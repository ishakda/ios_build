// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductAdapter extends TypeAdapter<Product> {
  @override
  final int typeId = 0;

  @override
  Product read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Product(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      price: fields[3] as double,
      discountPrice: fields[4] as double?,
      imageUrl: fields[5] as String,
      images: (fields[6] as List).cast<String>(),
      rating: fields[7] as double,
      reviewsCount: fields[8] as int,
      category: fields[9] as String,
      isFlashDeal: fields[10] as bool,
      stock: fields[11] as int,
      sellerId: fields[12] as String?,
      availableColors: (fields[13] as List).cast<String>(),
      availableSizes: (fields[14] as List).cast<String>(),
      detailImageUrls: (fields[15] as List).cast<String>(),
      brand: fields[16] as String?,
      parentCategory: fields[17] as String?,
      subCategory: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Product obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.discountPrice)
      ..writeByte(5)
      ..write(obj.imageUrl)
      ..writeByte(6)
      ..write(obj.images)
      ..writeByte(7)
      ..write(obj.rating)
      ..writeByte(8)
      ..write(obj.reviewsCount)
      ..writeByte(9)
      ..write(obj.category)
      ..writeByte(10)
      ..write(obj.isFlashDeal)
      ..writeByte(11)
      ..write(obj.stock)
      ..writeByte(12)
      ..write(obj.sellerId)
      ..writeByte(13)
      ..write(obj.availableColors)
      ..writeByte(14)
      ..write(obj.availableSizes)
      ..writeByte(15)
      ..write(obj.detailImageUrls)
      ..writeByte(16)
      ..write(obj.brand)
      ..writeByte(17)
      ..write(obj.parentCategory)
      ..writeByte(18)
      ..write(obj.subCategory);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
