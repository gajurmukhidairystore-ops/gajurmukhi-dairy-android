/// Shared domain contracts for the Gajurmukhi three-app platform.
///
/// These are transport models, not database tables. The cloud API remains the
/// source of truth for cross-device state; each Flutter app may cache them
/// locally for offline-first workflows.

enum PlatformRole { admin, shop, collector, delivery, customer }

enum OrderStatus { pending, accepted, preparing, ready, assigned, outForDelivery, delivered, cancelled }

enum PaymentStatus { unpaid, submitted, confirmed, rejected, refunded }

class CatalogItem {
  final String id;
  final String name;
  final String category;
  final String unit;
  final double salePrice;
  final double availableStock;
  final String barcode;

  const CatalogItem({required this.id, required this.name, required this.category, required this.unit, required this.salePrice, required this.availableStock, this.barcode = ''});

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'category': category, 'unit': unit, 'salePrice': salePrice, 'availableStock': availableStock, 'barcode': barcode};
}

class OrderLine {
  final String productId;
  final String name;
  final double quantity;
  final double unitPrice;

  const OrderLine({required this.productId, required this.name, required this.quantity, required this.unitPrice});

  double get total => quantity * unitPrice;
  Map<String, Object?> toJson() => {'productId': productId, 'name': name, 'quantity': quantity, 'unitPrice': unitPrice, 'total': total};
}

class CustomerOrder {
  final String id;
  final String customerId;
  final List<OrderLine> lines;
  final double total;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final String deliveryAddress;
  final String? deliveryAgentId;

  const CustomerOrder({required this.id, required this.customerId, required this.lines, required this.total, required this.status, required this.paymentStatus, required this.deliveryAddress, this.deliveryAgentId});

  Map<String, Object?> toJson() => {'id': id, 'customerId': customerId, 'lines': lines.map((line) => line.toJson()).toList(), 'total': total, 'status': status.name, 'paymentStatus': paymentStatus.name, 'deliveryAddress': deliveryAddress, 'deliveryAgentId': deliveryAgentId};
}

class FonepayPaymentSubmission {
  final String orderId;
  final double amount;
  final String paymentReference;
  final DateTime submittedAt;

  const FonepayPaymentSubmission({required this.orderId, required this.amount, required this.paymentReference, required this.submittedAt});
  Map<String, Object?> toJson() => {'orderId': orderId, 'amount': amount, 'paymentReference': paymentReference, 'submittedAt': submittedAt.toIso8601String()};
}

class DeliveryLocationPing {
  final String deliveryAgentId;
  final String orderId;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime recordedAt;

  const DeliveryLocationPing({required this.deliveryAgentId, required this.orderId, required this.latitude, required this.longitude, required this.accuracyMeters, required this.recordedAt});
  Map<String, Object?> toJson() => {'deliveryAgentId': deliveryAgentId, 'orderId': orderId, 'latitude': latitude, 'longitude': longitude, 'accuracyMeters': accuracyMeters, 'recordedAt': recordedAt.toIso8601String()};
}
