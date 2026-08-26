class LoanCalculator {
  const LoanCalculator._();

  static Map<String, dynamic> snapshot({
    required Map<String, Object?> loan,
    required List<Map<String, Object?>> payments,
    DateTime? asOf,
  }) {
    final closingDay = _day(asOf ?? DateTime.now());
    final startDay = _day(DateTime.tryParse('${loan['start_date'] ?? ''}') ?? closingDay);
    final rate = _number(loan['annual_interest_rate']);
    var remainingPrincipal = _number(loan['principal']);
    var accruedInterest = 0.0;
    var interestPaid = 0.0;
    var principalPaid = 0.0;
    var totalPaid = 0.0;
    var cursor = startDay;
    final statement = <Map<String, dynamic>>[];

    final ordered = [...payments]..sort((a, b) => '${a['payment_date']}'.compareTo('${b['payment_date']}'));
    for (final payment in ordered) {
      final paymentDay = _day(DateTime.tryParse('${payment['payment_date'] ?? ''}') ?? closingDay);
      if (paymentDay.isAfter(closingDay)) continue;
      final effectiveDay = paymentDay.isBefore(startDay) ? startDay : paymentDay;
      final days = effectiveDay.difference(cursor).inDays.clamp(0, 1000000);
      final interestForPeriod = remainingPrincipal * (rate / 100) * days / 365;
      accruedInterest += interestForPeriod;

      final amount = _number(payment['amount']);
      final interestPart = amount.clamp(0, accruedInterest).toDouble();
      final principalPart = (amount - interestPart).clamp(0, remainingPrincipal).toDouble();
      accruedInterest -= interestPart;
      remainingPrincipal -= principalPart;
      interestPaid += interestPart;
      principalPaid += principalPart;
      totalPaid += interestPart + principalPart;
      statement.add({
        'id': payment['id'],
        'date': effectiveDay.toIso8601String(),
        'amount': amount,
        'days': days,
        'interest_accrued': interestForPeriod,
        'interest_paid': interestPart,
        'principal_paid': principalPart,
        'remaining_principal': remainingPrincipal,
        'outstanding_interest': accruedInterest,
        'note': payment['note'] ?? '',
      });
      cursor = effectiveDay;
    }

    final finalDays = closingDay.difference(cursor).inDays.clamp(0, 1000000);
    final finalAccrual = remainingPrincipal * (rate / 100) * finalDays / 365;
    accruedInterest += finalAccrual;
    final today = _day(DateTime.now());
    final todayPaid = payments.where((payment) {
      final date = DateTime.tryParse('${payment['payment_date'] ?? ''}');
      return date != null && _day(date) == today;
    }).fold<double>(0, (sum, payment) => sum + _number(payment['amount']));

    return {
      'opening_principal': _number(loan['principal']),
      'annual_interest_rate': rate,
      'remaining_principal': remainingPrincipal,
      'outstanding_interest': accruedInterest,
      'remaining_total': remainingPrincipal + accruedInterest,
      'principal_paid': principalPaid,
      'interest_paid': interestPaid,
      'total_paid': totalPaid,
      'today_paid': todayPaid,
      'as_of': closingDay.toIso8601String(),
      'statement': statement,
    };
  }

  static double _number(Object? value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  static DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
}
