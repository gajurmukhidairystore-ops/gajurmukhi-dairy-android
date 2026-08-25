class DeliveryRouteService {
  static List<Map<String, Object?>> orderedStops(List<Map<String, Object?>> orders, {String? agentId}) {
    final visible = orders.where((order) {
      final status = '${order['status'] ?? ''}';
      final assigned = agentId == null || agentId.trim().isEmpty || '${order['delivery_agent_id'] ?? ''}' == agentId.trim();
      return assigned && status != 'DELIVERED' && status != 'CANCELLED';
    }).toList();
    visible.sort((a, b) {
      final stopA = (a['route_position'] as num?)?.toInt() ?? 1 << 30;
      final stopB = (b['route_position'] as num?)?.toInt() ?? 1 << 30;
      if (stopA != stopB) return stopA.compareTo(stopB);
      return '${a['delivery_at'] ?? a['created_at'] ?? ''}'.compareTo('${b['delivery_at'] ?? b['created_at'] ?? ''}');
    });
    return visible;
  }

  static bool canConfirmHandover({required String status, required bool arrivalUnlocked}) {
    return arrivalUnlocked && (status == 'OUT_FOR_DELIVERY' || status == 'DELIVERY_ATTEMPTED');
  }

  static String missingGoodsReminder({required String customerName, required String items, required String reason}) {
    final safeReason = reason.trim().isEmpty ? 'Handover was not confirmed' : reason.trim();
    return 'Confirm pending handover for $customerName: $items. Note: $safeReason';
  }
}
