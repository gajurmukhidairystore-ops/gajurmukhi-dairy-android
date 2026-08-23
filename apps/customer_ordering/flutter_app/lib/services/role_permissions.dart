class RolePermissions {
  const RolePermissions._();

  static int landingDestination(String role) {
    if (role == 'collector') return 4;
    return 0;
  }

  static bool canAccess(String role, int destination) {
    if (role == 'admin') return true;
    if (role == 'shop') return [0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12].contains(destination);
    if (role == 'collector') return [0, 4, 5, 6, 8, 9, 12].contains(destination);
    if (role == 'customer') return [0, 6, 8, 9, 10, 11, 12].contains(destination);
    return destination == 0;
  }

  static bool canCreateMilkCollection(String role) => role == 'admin' || role == 'collector';
  static bool canRemoveMilkCollection(String role) => role == 'admin';
  static bool canAssignDelivery(String role) => role == 'admin' || role == 'shop';
  static bool canTrackDelivery(String role) => role == 'admin' || role == 'shop' || role == 'collector';
  static bool canStartDeliveryTracking(String role) => role == 'collector';
  static bool canCallCustomer(String role) => role == 'admin' || role == 'shop' || role == 'collector';
}
