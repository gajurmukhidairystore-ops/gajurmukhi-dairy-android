import 'package:flutter_test/flutter_test.dart';
import 'package:gajurmukhi_dairy_business_pro/services/delivery_route_service.dart';

void main() {
  test('route stops sort by assigned stop number and exclude completed orders', () {
    final stops = DeliveryRouteService.orderedStops([
      {'id': 'three', 'delivery_agent_id': 'collector', 'route_position': 3, 'status': 'OUT_FOR_DELIVERY'},
      {'id': 'done', 'delivery_agent_id': 'collector', 'route_position': 1, 'status': 'DELIVERED'},
      {'id': 'one', 'delivery_agent_id': 'collector', 'route_position': 1, 'status': 'PENDING'},
      {'id': 'two', 'delivery_agent_id': 'collector', 'route_position': 2, 'status': 'CONFIRMED'},
    ], agentId: 'collector');
    expect(stops.map((row) => row['id']), ['one', 'two', 'three']);
  });

  test('handover confirmation requires arrival unlock and an active delivery status', () {
    expect(DeliveryRouteService.canConfirmHandover(status: 'OUT_FOR_DELIVERY', arrivalUnlocked: true), isTrue);
    expect(DeliveryRouteService.canConfirmHandover(status: 'OUT_FOR_DELIVERY', arrivalUnlocked: false), isFalse);
    expect(DeliveryRouteService.canConfirmHandover(status: 'PENDING', arrivalUnlocked: true), isFalse);
    expect(DeliveryRouteService.missingGoodsReminder(customerName: 'Hari', items: '2 L milk', reason: 'Customer unavailable'), contains('Customer unavailable'));
  });
}
