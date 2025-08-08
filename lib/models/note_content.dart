import 'dart:convert';

enum NoteType { text, image, video, file }

NoteType noteTypeFromString(String value) {
  switch (value) {
    case 'image':
      return NoteType.image;
    case 'video':
      return NoteType.video;
    case 'file':
      return NoteType.file;
    case 'text':
    default:
      return NoteType.text;
  }
}

String noteTypeToString(NoteType type) {
  switch (type) {
    case NoteType.image:
      return 'image';
    case NoteType.video:
      return 'video';
    case NoteType.file:
      return 'file';
    case NoteType.text:
      return 'text';
  }
}

class NoteContent {
  final NoteType type;
  final String? text; // for text notes
  final String? fileName; // for media notes
  final String? mimeType; // for media notes
  final String? dataBase64; // for media notes

  const NoteContent._({
    required this.type,
    this.text,
    this.fileName,
    this.mimeType,
    this.dataBase64,
  });

  factory NoteContent.text(String text) =>
      NoteContent._(type: NoteType.text, text: text);

  factory NoteContent.media({
    required NoteType type,
    required String fileName,
    required String mimeType,
    required String dataBase64,
  }) {
    return NoteContent._(
      type: type,
      fileName: fileName,
      mimeType: mimeType,
      dataBase64: dataBase64,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': noteTypeToString(type),
      if (type == NoteType.text) 'text': text ?? '',
      if (type != NoteType.text) 'fileName': fileName,
      if (type != NoteType.text) 'mimeType': mimeType,
      if (type != NoteType.text) 'dataBase64': dataBase64,
    };
  }

  String encode() => jsonEncode(toMap());

  static NoteContent fromMap(Map<String, dynamic> map) {
    final type = noteTypeFromString((map['type'] ?? 'text').toString());
    if (type == NoteType.text) {
      return NoteContent.text(map['text']?.toString() ?? '');
    } else {
      return NoteContent.media(
        type: type,
        fileName: map['fileName']?.toString() ?? 'file',
        mimeType: map['mimeType']?.toString() ?? 'application/octet-stream',
        dataBase64: map['dataBase64']?.toString() ?? '',
      );
    }
  }

  static NoteContent? tryParse(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic> && map.containsKey('type')) {
        return fromMap(map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
