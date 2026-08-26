enum GajurmukhiAppKind { admin, store, customer }

class AppProfile {
  final GajurmukhiAppKind kind;
  final String name;
  final String subtitle;

  const AppProfile({required this.kind, required this.name, required this.subtitle});

  static const admin = AppProfile(kind: GajurmukhiAppKind.admin, name: 'Gajurmukhi One', subtitle: 'Admin, Store, Collector, and Customer in one app');
  static const store = AppProfile(kind: GajurmukhiAppKind.store, name: 'Gajurmukhi Store', subtitle: 'Billing, payments, fulfillment, and stock');
  static const customer = AppProfile(kind: GajurmukhiAppKind.customer, name: 'Gajurmukhi Customer', subtitle: 'Shop, order, pay, and track delivery');

  static AppProfile current = admin;
}
