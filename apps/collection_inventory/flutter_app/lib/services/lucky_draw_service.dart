import 'dart:math';

class LuckyDrawService {
  static const minimumPurchase = 1000.0;

  static bool isEligiblePurchase(double total) => total >= minimumPurchase;

  static bool isDuplicateToken(Iterable<String> existingTokenNumbers, String candidate) => existingTokenNumbers.map((value) => value.trim()).contains(candidate.trim());

  static bool canAccessIdentityRecords(String role) => role == 'admin' || role == 'shop';

  static bool canDeleteIdentityRecord(String role) => role == 'admin';

  static int tokensForPurchase(double total) => isEligiblePurchase(total) ? 1 : 0;

  static String maskName(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    return words.map((word) {
      final first = word.substring(0, 1);
      return '$first${'*' * max(2, word.length - 1)}';
    }).join(' ');
  }

  static String publicWinnerLabel({required String tokenNumber, required String customerName}) =>
      '$tokenNumber · ${maskName(customerName)}';

  static List<Map<String, Object?>> selectWinners({
    required List<Map<String, Object?>> eligibleTokens,
    required List<Map<String, Object?>> prizes,
    int seed = 20260816,
  }) {
    final available = eligibleTokens.where((token) => '${token['status'] ?? 'ELIGIBLE'}' == 'ELIGIBLE').toList();
    if (available.isEmpty || prizes.isEmpty) return const [];
    available.shuffle(Random(seed));
    final winners = <Map<String, Object?>>[];
    final usedCustomers = <String>{};
    for (final prize in prizes) {
      if (winners.length >= available.length) break;
      Map<String, Object?>? selected;
      for (final token in available) {
        final customerId = '${token['customer_id'] ?? ''}';
        if (!usedCustomers.contains(customerId)) {
          selected = token;
          break;
        }
      }
      selected ??= available[winners.length];
      usedCustomers.add('${selected['customer_id'] ?? ''}');
      winners.add({
        'prize_rank': prize['prize_rank'],
        'prize_title': prize['prize_title'],
        'prize_description': prize['prize_description'],
        'token_number': selected['token_number'],
        'customer_id': selected['customer_id'],
        'customer_name': selected['customer_name'],
        'masked_name': maskName('${selected['customer_name'] ?? ''}'),
      });
    }
    return winners;
  }

  static String announcement({
    required String monthLabel,
    required String message,
    required List<Map<String, Object?>> winners,
  }) {
    final lines = <String>[
      '*GAJURMUKHI DAIRY & STORE*',
      '*Monthly Customer Lucky Draw — $monthLabel*',
      '',
      message.trim(),
      '',
    ];
    for (final winner in winners) {
      lines.add('${winner['prize_title']}: ${publicWinnerLabel(tokenNumber: '${winner['token_number']}', customerName: '${winner['customer_name']}')}');
    }
    lines.add('');
    lines.add('Congratulations. This was a free promotional draw for eligible purchases of NPR 1,000 or more.');
    return lines.join('\n');
  }
}
