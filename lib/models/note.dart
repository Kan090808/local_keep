import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

part 'note.g.dart';

@HiveType(typeId: 1)
enum NoteType {
  @HiveField(0)
  text,
  @HiveField(1)
  image,
  @HiveField(2)
  video,
  @HiveField(3)
  file,
}

@HiveType(typeId: 0)
class Note {
  @HiveField(0)
  final String? id;
  @HiveField(1)
  final String content;
  @HiveField(2)
  final DateTime createdAt;
  @HiveField(3)
  final DateTime updatedAt;
  @HiveField(4)
  final int orderIndex;
  @HiveField(5)
  final NoteType type;

  Note({
    this.id,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.orderIndex = 0,
    this.type = NoteType.text,
  });

  factory Note.create({required String content, NoteType type = NoteType.text}) {
    final now = DateTime.now();
    return Note(content: content, createdAt: now, updatedAt: now, type: type);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'order_index': orderIndex,
      'type': type.index,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      content: map['content'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      orderIndex: map['order_index'] ?? 0,
      type: NoteType.values[map['type'] ?? 0],
    );
  }

  Note copyWith({
    String? id,
    String? content,
    DateTime? updatedAt,
    int? orderIndex,
    NoteType? type,
  }) {
    return Note(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      orderIndex: orderIndex ?? this.orderIndex,
      type: type ?? this.type,
    );
  }

  String get formattedDate {
    return DateFormat('MMM dd, yyyy HH:mm').format(updatedAt);
  }
}
