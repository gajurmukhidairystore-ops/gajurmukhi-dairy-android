import 'package:flutter_test/flutter_test.dart';
import 'package:gajurmukhi_dairy_business_pro/services/loan_calculator.dart';

void main() {
  test('daily reducing-balance interest is allocated before principal and produces a clear statement', () {
    final result = LoanCalculator.snapshot(
      loan: {'principal': 36500, 'annual_interest_rate': 10, 'start_date': '2026-01-01T00:00:00.000'},
      payments: [{'id': 'pay-1', 'payment_date': '2026-01-11T00:00:00.000', 'amount': 200, 'note': 'Daily repayment'}],
      asOf: DateTime(2026, 1, 21),
    );

    expect(result['interest_paid'], closeTo(100, 0.001));
    expect(result['principal_paid'], closeTo(100, 0.001));
    expect(result['remaining_principal'], closeTo(36400, 0.001));
    expect(result['outstanding_interest'], closeTo(99.726, 0.001));
    expect(result['remaining_total'], closeTo(36499.726, 0.001));
    final statement = result['statement'] as List<Map<String, dynamic>>;
    expect(statement.single['days'], 10);
    expect(statement.single['interest_paid'], closeTo(100, 0.001));
    expect(statement.single['principal_paid'], closeTo(100, 0.001));
  });

  test('daily payment total only includes repayments entered for today', () {
    final today = DateTime.now();
    final result = LoanCalculator.snapshot(
      loan: {'principal': 1000, 'annual_interest_rate': 0, 'start_date': today.subtract(const Duration(days: 2)).toIso8601String()},
      payments: [
        {'payment_date': today.toIso8601String(), 'amount': 125},
        {'payment_date': today.subtract(const Duration(days: 1)).toIso8601String(), 'amount': 75},
      ],
      asOf: today,
    );

    expect(result['today_paid'], 125);
    expect(result['total_paid'], 200);
    expect(result['remaining_principal'], 800);
  });
}
