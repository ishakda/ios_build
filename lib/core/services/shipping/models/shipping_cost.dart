class ShippingCost {
  final String wilayaLabel;
  final String wilayaId;
  final double homeCost;
  final double stopdeskCost;

  ShippingCost({
    required this.wilayaLabel,
    required this.wilayaId,
    required this.homeCost,
    required this.stopdeskCost,
  });

  factory ShippingCost.fromMap(Map<String, dynamic> json, String carrierId) {
    if (carrierId == 'elogistia') {
      return ShippingCost(
        wilayaLabel: json['wilayaLabel'] ?? '',
        wilayaId: json['wilayaID']?.toString() ?? '',
        homeCost: double.tryParse(json['home']?.toString() ?? '0') ?? 0.0,
        stopdeskCost: double.tryParse(json['stopdesk']?.toString() ?? '0') ?? 0.0,
      );
    }
    // Basic mapping for Yalidine/ZR if they provide it in get-carrier-checkout-data
    return ShippingCost(
      wilayaLabel: json['wilaya_name'] ?? json['name'] ?? '',
      wilayaId: json['id']?.toString() ?? '',
      homeCost: double.tryParse(json['home_fee']?.toString() ?? '0') ?? 0.0,
      stopdeskCost: double.tryParse(json['desk_fee']?.toString() ?? '0') ?? 0.0,
    );
  }
}
