import 'package:intl/intl.dart';

class Note {
  final int? id;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int orderIndex;
  
  Note({
    this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.orderIndex = 0,
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
      'order_index': orderIndex,
    };
  }
  
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      orderIndex: map['order_index'] ?? 0,
    );
  }
  
  Note copyWith({
    int? id,
    String? content,
    DateTime? updatedAt,
    int? orderIndex,
  }) {
    return Note(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
  
  String get formattedDate {
    return DateFormat('MMM dd, yyyy HH:mm').format(updatedAt);
  }
}