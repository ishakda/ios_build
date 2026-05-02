class ElogistiaShippingCost {
  final String wilayaLabel;
  final String wilayaId;
  final String home;
  final String stopdesk;

  ElogistiaShippingCost({
    required this.wilayaLabel,
    required this.wilayaId,
    required this.home,
    required this.stopdesk,
  });

  factory ElogistiaShippingCost.fromJson(Map<String, dynamic> json) {
    return ElogistiaShippingCost(
      wilayaLabel: json['wilayaLabel'] ?? '',
      wilayaId: json['wilayaID'] ?? '',
      home: json['home'] ?? '0',
      stopdesk: json['stopdesk'] ?? '0',
    );
  }

  double get homeCost => double.tryParse(home) ?? 0.0;
  double get stopdeskCost => double.tryParse(stopdesk) ?? 0.0;
}

class ShippingCostResponse {
  final List<ElogistiaShippingCost> body;
  final int itemCount;

  ShippingCostResponse({required this.body, required this.itemCount});

  factory ShippingCostResponse.fromJson(Map<String, dynamic> json) {
    return ShippingCostResponse(
      body: (json['body'] as List? ?? [])
          .map((e) => ElogistiaShippingCost.fromJson(e))
          .toList(),
      itemCount: json['itemCount'] ?? 0,
    );
  }
}
