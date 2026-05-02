// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 1;

  @override
  User read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return User(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
      profileImageUrl: fields[3] as String?,
      phoneNumber: fields[4] as String?,
      role: fields[5] as String,
      storeName: fields[6] as String?,
      storeDescription: fields[7] as String?,
      storeLogo: fields[8] as String?,
      isSellerApproved: fields[9] as bool,
      isVerifiedSeller: fields[10] as bool,
      verificationLevel: fields[11] as String,
      trustScore: fields[12] as double,
      isBanned: fields[13] as bool,
      banReason: fields[14] as String?,
      isCodBlocked: fields[15] as bool,
      isEmailVerified: fields[16] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.email)
      ..writeByte(3)
      ..write(obj.profileImageUrl)
      ..writeByte(4)
      ..write(obj.phoneNumber)
      ..writeByte(5)
      ..write(obj.role)
      ..writeByte(6)
      ..write(obj.storeName)
      ..writeByte(7)
      ..write(obj.storeDescription)
      ..writeByte(8)
      ..write(obj.storeLogo)
      ..writeByte(9)
      ..write(obj.isSellerApproved)
      ..writeByte(10)
      ..write(obj.isVerifiedSeller)
      ..writeByte(11)
      ..write(obj.verificationLevel)
      ..writeByte(12)
      ..write(obj.trustScore)
      ..writeByte(13)
      ..write(obj.isBanned)
      ..writeByte(14)
      ..write(obj.banReason)
      ..writeByte(15)
      ..write(obj.isCodBlocked)
      ..writeByte(16)
      ..write(obj.isEmailVerified);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
