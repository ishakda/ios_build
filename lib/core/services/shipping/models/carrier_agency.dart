class CarrierAgency {
  final String id;
  final String name;
  final String wilayaId;
  final String commune;

  CarrierAgency({
    required this.id,
    required this.name,
    required this.wilayaId,
    required this.commune,
  });

  factory CarrierAgency.fromMap(Map<String, dynamic> json, String carrierId) {
    if (carrierId == 'elogistia') {
      return CarrierAgency(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        wilayaId: json['wilayaID']?.toString() ?? '',
        commune: json['commune']?.toString() ?? '',
      );
    }
    
    if (carrierId == 'yalidine') {
       return CarrierAgency(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        wilayaId: json['wilaya_id']?.toString() ?? '',
        commune: json['commune_name']?.toString() ?? '',
      );
    }

    // ZR Express
    return CarrierAgency(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      wilayaId: json['wilaya_id']?.toString() ?? '',
      commune: json['commune']?.toString() ?? '',
    );
  }
}
