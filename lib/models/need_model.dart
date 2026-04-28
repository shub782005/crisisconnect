import 'package:cloud_firestore/cloud_firestore.dart';
 
class NeedModel {
  final String id;
  final String type; // food, medical, shelter, water, clothing
  final String description;
  final double lat;
  final double lng;
  final String address;
  final int peopleAffected;
  final String urgencyLevel; // high, medium, low
  final double priorityScore;
  final String status; // pending, assigned, in_progress, completed
  final String? assignedVolunteerId;
  final String reportedBy;
  final DateTime createdAt;
  final String? imageUrl;
 
  NeedModel({
    required this.id,
    required this.type,
    required this.description,
    required this.lat,
    required this.lng,
    required this.address,
    required this.peopleAffected,
    required this.urgencyLevel,
    required this.priorityScore,
    required this.status,
    this.assignedVolunteerId,
    required this.reportedBy,
    required this.createdAt,
    this.imageUrl,
  });
 
  factory NeedModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NeedModel(
      id: doc.id,
      type: data['type'] ?? 'food',
      description: data['description'] ?? '',
      lat: (data['location']?['lat'] ?? 0.0).toDouble(),
      lng: (data['location']?['lng'] ?? 0.0).toDouble(),
      address: data['location']?['address'] ?? '',
      peopleAffected: data['peopleAffected'] ?? 0,
      urgencyLevel: data['urgencyLevel'] ?? 'medium',
      priorityScore: (data['priorityScore'] ?? 0.5).toDouble(),
      status: data['status'] ?? 'pending',
      assignedVolunteerId: data['assignedVolunteerId'],
      reportedBy: data['reportedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'],
    );
  }
 
  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'description': description,
      'location': {'lat': lat, 'lng': lng, 'address': address},
      'peopleAffected': peopleAffected,
      'urgencyLevel': urgencyLevel,
      'priorityScore': priorityScore,
      'status': status,
      'assignedVolunteerId': assignedVolunteerId,
      'reportedBy': reportedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'imageUrl': imageUrl,
    };
  }
}
 