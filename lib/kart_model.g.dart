// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kart_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class KartModelAdapter extends TypeAdapter<KartModel> {
  @override
  final int typeId = 15;

  @override
  KartModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KartModel(
      id: fields[0] as String,
      baslik: fields[1] as String,
      resimYolu: fields[2] as String?,
      sesYolu: fields[3] as String?,
      studentId: (fields[4] as String?) ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, KartModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.baslik)
      ..writeByte(2)
      ..write(obj.resimYolu)
      ..writeByte(3)
      ..write(obj.sesYolu)
      ..writeByte(4)
      ..write(obj.studentId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KartModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
