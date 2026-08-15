import 'package:flutter/material.dart';
import '../../providers/business_provider.dart';

class ReportsScreen extends StatelessWidget {
  final BusinessProvider p;
  const ReportsScreen(this.p, {super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('Reports & Analytics', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      _report('Sales', p.totals['sales'] ?? 0),
      _report('Collections', p.totals['collection'] ?? 0),
      _report('Expenses', p.totals['expenses'] ?? 0),
      _report('Customer Due', p.totals['due'] ?? 0),
      _report('Milk Collected (L)', p.totals['milkLitres'] ?? 0),
      const SizedBox(height: 16),
      const Text('Production reports to add: milk yield, paneer yield, ghee yield, dahi production, product margin, farmer settlement, daily/monthly profit and cash flow.'),
    ],
  );

  Widget _report(String title, num value) => Card(
    child: ListTile(
      title: Text(title),
      trailing: Text(value.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}
