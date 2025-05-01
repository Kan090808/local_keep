import 'package:intl/intl.dart';

class Note {
  final int? id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  Note({
    this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory Note.create({required String content}) {
    final now = DateTime.now();
    return Note(
      content: content,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
  
  Note copyWith({
    int? id,
    String? content,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
  
  String get formattedDate {
    return DateFormat('MMM dd, yyyy HH:mm').format(updatedAt);
  }
}