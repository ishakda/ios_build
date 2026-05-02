import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/services/elogistia/models/agency.dart';
import 'package:untitled1/core/services/elogistia/models/shipping_cost.dart';

class ElogistiaCheckoutData {
  const ElogistiaCheckoutData({
    required this.shippingCosts,
    required this.agencies,
  });

  final List<ElogistiaShippingCost> shippingCosts;
  final List<ElogistiaAgency> agencies;
}

class ElogistiaService {
  Future<ElogistiaCheckoutData> getCheckoutData() async {
    final response = await SupabaseService.client.functions.invoke(
      'get-elogistia-checkout-data',
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception('Invalid Elogistia checkout response');
    }

    final payload = Map<String, dynamic>.from(data);
    final shippingCosts = (payload['shippingCosts'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              ElogistiaShippingCost.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    final agencies = (payload['agencies'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => ElogistiaAgency.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();

    return ElogistiaCheckoutData(
      shippingCosts: shippingCosts,
      agencies: agencies,
    );
  }
}
