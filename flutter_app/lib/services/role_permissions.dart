class RolePermissions {
  const RolePermissions._();

  static int landingDestination(String role) {
    if (role == 'collector') return 4;
    return 0;
  }

  static bool canAccess(String role, int destination) {
    if (role == 'admin') return true;
    if (role == 'shop') return [0, 1, 2, 3, 5, 7].contains(destination);
    if (role == 'collector') return [0, 4, 5].contains(destination);
    return destination == 0;
  }
}
