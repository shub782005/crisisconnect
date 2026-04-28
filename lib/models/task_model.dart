import 'package:cloud_firestore/cloud_firestore.dart';
 
class TaskModel {
  final String id;
  final String needId;
  final String volunteerId;
  final String status; // assigned, on_the_way, completed, rejected
  final double matchScore;
  final String matchReason; // EXPLAINABILITY feature
  final DateTime assignedAt;
  final DateTime? completedAt;
  final String? volunteerNotes;
 
  TaskModel({
    required this.id,
    required this.needId,
    required this.volunteerId,
    required this.status,
    required this.matchScore,
    required this.matchReason,
    required this.assignedAt,
    this.completedAt,
    this.volunteerNotes,
  });
 
  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      needId: data['needId'] ?? '',
      volunteerId: data['volunteerId'] ?? '',
      status: data['status'] ?? 'assigned',
      matchScore: (data['matchScore'] ?? 0.0).toDouble(),
      matchReason: data['matchReason'] ?? '',
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      volunteerNotes: data['volunteerNotes'],
    );
  }
}