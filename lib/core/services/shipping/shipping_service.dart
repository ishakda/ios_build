import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/core/services/shipping/models/carrier_agency.dart';
import 'package:untitled1/core/services/shipping/models/shipping_cost.dart';

class CarrierCheckoutData {
  const CarrierCheckoutData({
    required this.shippingCosts,
    required this.agencies,
  });

  final List<ShippingCost> shippingCosts;
  final List<CarrierAgency> agencies;
}

class ShippingService {
  Future<CarrierCheckoutData> getCarrierData(String carrierId) async {
    final response = await SupabaseService.client.functions.invoke(
      'get-carrier-checkout-data',
      body: {'carrierId': carrierId},
    );

    final data = response.data;
    if (data is! Map) {
      throw Exception('Invalid carrier checkout response');
    }

    final payload = Map<String, dynamic>.from(data);
    
    // Normalize response based on carrier if needed, or handle in factory methods
    final shippingCosts = (payload['shippingCosts'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ShippingCost.fromMap(Map<String, dynamic>.from(item), carrierId))
        .toList();
        
    final agencies = (payload['agencies'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CarrierAgency.fromMap(Map<String, dynamic>.from(item), carrierId))
        .toList();

    return CarrierCheckoutData(
      shippingCosts: shippingCosts,
      agencies: agencies,
    );
  }

  Future<void> createShipment({
    required String carrierId,
    required String orderId,
  }) async {
    await SupabaseService.client.functions.invoke(
      'create-shipment',
      body: {
        'orderId': orderId,
        'carrierId': carrierId,
      },
    );
  }
}
