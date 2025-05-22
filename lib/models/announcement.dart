import 'package:flutter/foundation.dart';
import 'pet.dart';
import 'user.dart';

class Announcement {
  final int id;
  final int userId;
  final int petId;
  final String? keywords;
  final String? description;
  final String status;
  final String timestamp;
  final String? location;
  final List<String> imagePaths;
  final User? user;
  final Pet pet;

  Announcement({
    required this.id,
    required this.userId,
    required this.petId,
    this.keywords,
    this.description,
    required this.status,
    required this.timestamp,
    this.location,
    required this.imagePaths,
    this.user,
    required this.pet,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    debugPrint('Parsing Announcement JSON: $json');
    final imagePaths = json['image_paths'] != null
        ? (json['image_paths'] as List<dynamic>)
            .where((item) => item is String)
            .cast<String>()
            .toList()
        : <String>[];
    debugPrint('Parsed imagePaths: $imagePaths');
    return Announcement(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      petId: json['pet_id'] as int? ?? 0,
      keywords: json['keywords'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      location: json['location'] as String?,
      imagePaths: imagePaths,
      user: json['user'] != null ? User.fromJson(json['user'] as Map<String, dynamic>) : null,
      pet: Pet.fromJson(json['pet'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'pet_id': petId,
        'keywords': keywords,
        'description': description,
        'status': status,
        'timestamp': timestamp,
        'location': location,
        'image_paths': imagePaths,
        'user': user?.toJson(),
        'pet': pet.toJson(),
      };
}
