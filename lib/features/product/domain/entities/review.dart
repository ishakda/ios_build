import 'package:equatable/equatable.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/utils/text_normalizer.dart';

class Review extends Equatable {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String userImageUrl;
  final double rating;
  final String comment;
  final bool isVerifiedPurchase;
  final bool isModerated;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.userImageUrl,
    required this.rating,
    required this.comment,
    this.isVerifiedPurchase = false,
    this.isModerated = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'userId': userId,
      'userName': userName,
      'userImageUrl': userImageUrl,
      'rating': rating,
      'comment': comment,
      'isVerifiedPurchase': isVerifiedPurchase,
      'isModerated': isModerated,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      userId: map['userId'] ?? '',
      userName: normalizeText(map['userName']?.toString() ?? ''),
      userImageUrl: map['userImageUrl'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: normalizeText(map['comment']?.toString() ?? ''),
      isVerifiedPurchase: map['isVerifiedPurchase'] == true,
      isModerated: map['isModerated'] != false,
      createdAt: SupabaseService.parseDateTime(map['createdAt']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    productId,
    userId,
    userName,
    userImageUrl,
    rating,
    comment,
    isVerifiedPurchase,
    isModerated,
    createdAt,
  ];
}
