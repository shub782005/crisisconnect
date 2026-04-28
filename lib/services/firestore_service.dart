import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/need_model.dart';
import '../models/volunteer_model.dart';
import '../models/task_model.dart';
 
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
 
  // ---- NEEDS ----
 
  Stream<List<NeedModel>> getNeedsStream() {
    return _db
        .collection('needs')
        .orderBy('priorityScore', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(NeedModel.fromFirestore).toList());
  }
 
  Future<void> addNeed(NeedModel need) async {
    await _db.collection('needs').add(need.toFirestore());
  }
 
  Future<void> updateNeedStatus(String needId, String status, {String? volunteerId}) async {
    final update = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (volunteerId != null) update['assignedVolunteerId'] = volunteerId;
    await _db.collection('needs').doc(needId).update(update);
  }
 
  // ---- VOLUNTEERS ----
 
  Future<List<VolunteerModel>> getAvailableVolunteers() async {
    final snap = await _db
        .collection('volunteers')
        .where('isAvailable', isEqualTo: true)
        .get();
    return snap.docs.map(VolunteerModel.fromFirestore).toList();
  }
 
  Future<void> updateVolunteerAvailability(String uid, bool isAvailable) async {
    await _db.collection('volunteers').doc(uid).update({
      'isAvailable': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
 
  // ---- TASKS ----
 
  Future<void> createTask(TaskModel task) async {
    await _db.collection('tasks').add({
      'needId': task.needId,
      'volunteerId': task.volunteerId,
      'status': task.status,
      'matchScore': task.matchScore,
      'matchReason': task.matchReason,
      'assignedAt': FieldValue.serverTimestamp(),
    });
  }
 
  Stream<List<TaskModel>> getVolunteerTasksStream(String volunteerId) {
    return _db
        .collection('tasks')
        .where('volunteerId', isEqualTo: volunteerId)
        .where('status', whereIn: ['assigned', 'on_the_way'])
        .snapshots()
        .map((snap) => snap.docs.map(TaskModel.fromFirestore).toList());
  }
 
  Future<void> updateTaskStatus(String taskId, String status, {String? notes}) async {
    final update = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (notes != null) update['volunteerNotes'] = notes;
    if (status == 'completed') update['completedAt'] = FieldValue.serverTimestamp();
    await _db.collection('tasks').doc(taskId).update(update);
  }
 
  // ---- IMPACT ANALYTICS ----
 
  Future<Map<String, int>> getImpactStats() async {
    final needs = await _db.collection('needs').get();
    int totalNeeds = needs.docs.length;
    int completed = needs.docs.where((d) => d['status'] == 'completed').length;
    int peopleHelped = needs.docs
        .where((d) => d['status'] == 'completed')
        .fold(0, (acc, d) => acc + (d['peopleAffected'] as int? ?? 0));
 
    return {
      'totalNeeds': totalNeeds,
      'completed': completed,
      'peopleHelped': peopleHelped,
      'pending': totalNeeds - completed,
    };
  }
}