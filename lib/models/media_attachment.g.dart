// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_attachment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MediaAttachmentAdapter extends TypeAdapter<MediaAttachment> {
  @override
  final int typeId = 1;

  @override
  MediaAttachment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaAttachment(
      id: fields[0] as String,
      fileName: fields[1] as String,
      encryptedData: fields[2] as String,
      mediaTypeIndex: fields[3] as int,
      fileSize: fields[4] as int,
      mimeType: fields[5] as String?,
      createdAt: fields[6] as DateTime,
      thumbnailData: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MediaAttachment obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.encryptedData)
      ..writeByte(3)
      ..write(obj.mediaTypeIndex)
      ..writeByte(4)
      ..write(obj.fileSize)
      ..writeByte(5)
      ..write(obj.mimeType)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.thumbnailData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaAttachmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
