import 'package:cloud_firestore/cloud_firestore.dart';
 
class VolunteerModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final double lat;
  final double lng;
  final List<String> skills;
  final bool isAvailable;
  final int activeTasks;
  final int completedTasks;
  final double trustScore;
  final String? fcmToken;
 
  VolunteerModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.lat,
    required this.lng,
    required this.skills,
    required this.isAvailable,
    required this.activeTasks,
    required this.completedTasks,
    required this.trustScore,
    this.fcmToken,
  });
 
  factory VolunteerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VolunteerModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      lat: (data['location']?['lat'] ?? 0.0).toDouble(),
      lng: (data['location']?['lng'] ?? 0.0).toDouble(),
      skills: List<String>.from(data['skills'] ?? []),
      isAvailable: data['isAvailable'] ?? true,
      activeTasks: data['activeTasks'] ?? 0,
      completedTasks: data['completedTasks'] ?? 0,
      trustScore: (data['trustScore'] ?? 0.5).toDouble(),
      fcmToken: data['fcmToken'],
    );
  }
 
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'location': {'lat': lat, 'lng': lng},
      'skills': skills,
      'isAvailable': isAvailable,
      'activeTasks': activeTasks,
      'completedTasks': completedTasks,
      'trustScore': trustScore,
      'fcmToken': fcmToken,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
 