import 'package:cloud_firestore/cloud_firestore.dart';

class TicketModel {
  final String id;
  final String userId;
  final String category;
  final String subject;
  final String description;
  final String status; // 'Open', 'In Progress', 'Closed'
  final DateTime createdAt;
  final String? adminResponse;

  TicketModel({
    required this.id,
    required this.userId,
    required this.category,
    required this.subject,
    required this.description,
    this.status = 'Open',
    required this.createdAt,
    this.adminResponse,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'category': category,
      'subject': subject,
      'description': description,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'adminResponse': adminResponse,
    };
  }

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      category: json['category'] ?? 'General',
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'Open',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      adminResponse: json['adminResponse'],
    );
  }
}
