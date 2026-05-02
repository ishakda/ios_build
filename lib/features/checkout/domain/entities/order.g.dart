// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderAdapter extends TypeAdapter<Order> {
  @override
  final int typeId = 3;

  @override
  Order read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Order(
      id: fields[0] as String,
      items: (fields[1] as List).cast<CartItem>(),
      totalAmount: fields[2] as double,
      orderDate: fields[3] as DateTime,
      status: fields[4] as String,
      buyerId: fields[5] as String,
      sellerIds: (fields[6] as List).cast<String>(),
      orderNumber: fields[7] as String,
      shippingFee: fields[8] as double? ?? 0,
      deliveryType: fields[9] as String? ?? 'home',
      paymentMethod: fields[10] as String? ?? 'cod',
      shippingAddress: (fields[11] as Map?)?.cast<String, dynamic>() ?? const {},
      paymentStatus: fields[12] as String? ?? 'pending',
    );
  }

  @override
  void write(BinaryWriter writer, Order obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.items)
      ..writeByte(2)
      ..write(obj.totalAmount)
      ..writeByte(3)
      ..write(obj.orderDate)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.buyerId)
      ..writeByte(6)
      ..write(obj.sellerIds)
      ..writeByte(7)
      ..write(obj.orderNumber)
      ..writeByte(8)
      ..write(obj.shippingFee)
      ..writeByte(9)
      ..write(obj.deliveryType)
      ..writeByte(10)
      ..write(obj.paymentMethod)
      ..writeByte(11)
      ..write(obj.shippingAddress)
      ..writeByte(12)
      ..write(obj.paymentStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
