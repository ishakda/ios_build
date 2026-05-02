import 'package:hive/hive.dart';
import 'package:untitled1/core/utils/text_normalizer.dart';

part 'user.g.dart';

@HiveType(typeId: 1)
class User extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String email;
  @HiveField(3)
  final String? profileImageUrl;
  @HiveField(4)
  final String? phoneNumber;
  @HiveField(5)
  final String role; // 'buyer' or 'seller'
  @HiveField(6)
  final String? storeName;
  @HiveField(7)
  final String? storeDescription;
  @HiveField(8)
  final String? storeLogo;
  @HiveField(9)
  final bool isSellerApproved;
  @HiveField(10)
  final bool isVerifiedSeller;
  @HiveField(11)
  final String verificationLevel;
  @HiveField(12)
  final double trustScore;
  @HiveField(13)
  final bool isBanned;
  @HiveField(14)
  final String? banReason;
  @HiveField(15)
  final bool isCodBlocked;
  @HiveField(16)
  final bool isEmailVerified;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.phoneNumber,
    this.role = 'buyer',
    this.storeName,
    this.storeDescription,
    this.storeLogo,
    this.isSellerApproved = false,
    this.isVerifiedSeller = false,
    this.verificationLevel = 'none',
    this.trustScore = 0,
    this.isBanned = false,
    this.banReason,
    this.isCodBlocked = false,
    this.isEmailVerified = false,
  });

  bool get isSeller => role == 'seller';

  bool get isAdmin => role == 'admin';

  bool get canSellProducts => isSeller && isSellerApproved && !isBanned;

  bool get hasPhoneNumber => phoneNumber?.trim().isNotEmpty == true;

  bool get canPublishProducts =>
      isSeller &&
      isSellerApproved &&
      isEmailVerified &&
      hasPhoneNumber &&
      !isBanned;

  String? get sellerPublishingBlocker {
    if (!isSeller) return 'Only seller accounts can publish products.';
    if (isBanned) return 'Your seller account is suspended.';
    if (!isSellerApproved) {
      return 'Your seller account is waiting for admin approval.';
    }
    if (!isEmailVerified) {
      return 'Verify your email before publishing products.';
    }
    if (!hasPhoneNumber) {
      return 'Add a phone number before publishing products.';
    }
    return null;
  }

  bool get hasPendingSellerApproval =>
      isSeller && !isSellerApproved && !isBanned;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'phoneNumber': phoneNumber,
      'role': role,
      'storeName': storeName,
      'storeDescription': storeDescription,
      'storeLogo': storeLogo,
      'isSellerApproved': isSellerApproved,
      'isVerifiedSeller': isVerifiedSeller,
      'verificationLevel': verificationLevel,
      'trustScore': trustScore,
      'isBanned': isBanned,
      'banReason': banReason,
      'isCodBlocked': isCodBlocked,
      'isEmailVerified': isEmailVerified,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    final rawTrustScore = map['trustScore'];
    return User(
      id: map['id'] ?? '',
      name: normalizeText(map['name']?.toString() ?? ''),
      email: map['email'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      phoneNumber: map['phoneNumber'],
      role: map['role'] ?? 'buyer',
      storeName: normalizeNullableText(map['storeName']?.toString()),
      storeDescription:
          normalizeNullableText(map['storeDescription']?.toString()),
      storeLogo: map['storeLogo'],
      isSellerApproved: map['isSellerApproved'] == true,
      isVerifiedSeller: map['isVerifiedSeller'] == true,
      verificationLevel: map['verificationLevel'] ?? 'none',
      trustScore: rawTrustScore is num
          ? rawTrustScore.toDouble()
          : double.tryParse(rawTrustScore?.toString() ?? '') ?? 0,
      isBanned: map['isBanned'] == true,
      banReason: normalizeNullableText(map['banReason']?.toString()),
      isCodBlocked: map['isCodBlocked'] == true,
      isEmailVerified: map['isEmailVerified'] == true,
    );
  }

  User copyWith({
    String? name,
    String? email,
    String? profileImageUrl,
    String? phoneNumber,
    String? role,
    String? storeName,
    String? storeDescription,
    String? storeLogo,
    bool? isSellerApproved,
    bool? isVerifiedSeller,
    String? verificationLevel,
    double? trustScore,
    bool? isBanned,
    String? banReason,
    bool? isCodBlocked,
    bool? isEmailVerified,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      storeName: storeName ?? this.storeName,
      storeDescription: storeDescription ?? this.storeDescription,
      storeLogo: storeLogo ?? this.storeLogo,
      isSellerApproved: isSellerApproved ?? this.isSellerApproved,
      isVerifiedSeller: isVerifiedSeller ?? this.isVerifiedSeller,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      trustScore: trustScore ?? this.trustScore,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      isCodBlocked: isCodBlocked ?? this.isCodBlocked,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }
}
