class WelcomeService {
  static String greetingFor(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return 'Admin';
      case 'shop': return 'Store';
      case 'collector': return 'Collector';
      case 'customer': return 'Customer';
      default: return role.isEmpty ? 'User' : role[0].toUpperCase() + role.substring(1);
    }
  }

  static String message({required DateTime time, required String name, required String role}) {
    final displayName = name.trim().isEmpty ? 'there' : name.trim();
    return '${greetingFor(time)}, $displayName · ${roleLabel(role)}. Welcome to Gajurmukhi One.';
  }
}
