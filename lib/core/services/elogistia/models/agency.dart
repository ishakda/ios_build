class ElogistiaAgency {
  final String id;
  final String name;
  final String wilayaId;
  final String commune;
  final String address;

  ElogistiaAgency({
    required this.id,
    required this.name,
    required this.wilayaId,
    required this.commune,
    required this.address,
  });

  factory ElogistiaAgency.fromJson(Map<String, dynamic> json) {
    final name = (json['Nom du bureau'] ?? json['nom'] ?? json['name'] ?? '')
        .toString();
    final wilayaId =
        (json['Code wilaya'] ?? json['wilaya_id'] ?? json['wilayaID'] ?? '')
            .toString();
    final commune = (json['Commune'] ?? json['commune'] ?? '').toString();
    final address =
        (json['Adresse'] ?? json['adresse'] ?? json['address'] ?? '')
            .toString();

    return ElogistiaAgency(
      id: (json['id']?.toString().trim().isNotEmpty == true)
          ? json['id'].toString()
          : '${wilayaId}_${commune}_$name',
      name: name,
      wilayaId: wilayaId,
      commune: commune,
      address: address,
    );
  }
}
