import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/need_model.dart';
import '../services/firestore_service.dart';
import '../services/matching_service.dart';
import '../services/notification_service.dart';

class TaskProvider extends ChangeNotifier {
  final _firestoreService = FirestoreService();

  List<TaskModel> _tasks = [];
  bool _isLoading = false;

  List<TaskModel> get tasks => _tasks;
  bool get isLoading => _isLoading;

  void startListeningForVolunteer(String volunteerId) {
    _firestoreService.getVolunteerTasksStream(volunteerId).listen((tasks) {
      _tasks = tasks;
      notifyListeners();
    });
  }

  Future<bool> assignTask({
    required NeedModel need,
    required MatchResult match,
    String volunteerName = '',
  }) async {
    _isLoading = true; notifyListeners();
    try {
      final task = TaskModel(
        id: '',
        needId: need.id,
        volunteerId: match.volunteerId,
        status: 'assigned',
        matchScore: match.matchScore,
        matchReason: match.explanation,
        assignedAt: DateTime.now(),
      );
      await _firestoreService.createTask(task);
      await _firestoreService.updateNeedStatus(
        need.id, 'assigned', volunteerId: match.volunteerId);

      // 🔔 Notify volunteer of assignment
      await NotificationService.notifyTaskAssigned(
        volunteerName: match.volunteerName,
        needType: need.type,
        urgencyLevel: need.urgencyLevel,
        location: need.address,
      );

      // 🔔 Broadcast if high urgency
      if (need.urgencyLevel == 'high') {
        await NotificationService.broadcastCrisisAlert(
          needType: need.type,
          location: need.address,
          peopleAffected: need.peopleAffected,
        );
      }

      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> updateTaskStatus(String taskId, String status,
      {NeedModel? need, String volunteerName = ''}) async {
    await _firestoreService.updateTaskStatus(taskId, status);

    // 🔔 Notify admin when completed
    if (status == 'completed' && need != null) {
      await NotificationService.notifyTaskCompleted(
        volunteerName: volunteerName,
        needType: need.type,
        peopleHelped: need.peopleAffected,
      );
    }
  }
}
