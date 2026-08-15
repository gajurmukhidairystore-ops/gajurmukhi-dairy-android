import 'package:flutter/material.dart';
import '../../providers/business_provider.dart';

class DashboardScreen extends StatelessWidget {
  final BusinessProvider p;
  const DashboardScreen(this.p, {super.key});

  Widget metric(String title, num value, IconData icon) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text('NPR ${value.toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    ),
  );

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: p.refresh,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Namaste 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const Text('Good morning — here is your business today.'),
        const SizedBox(height: 16),
        metric('Today Sales', p.totals['sales'] ?? 0, Icons.trending_up),
        metric('Collection', p.totals['collection'] ?? 0, Icons.payments),
        metric('Customer Due', p.totals['due'] ?? 0, Icons.account_balance_wallet),
        metric('Milk Collected', p.totals['milkLitres'] ?? 0, Icons.local_drink),
        metric('Expenses', p.totals['expenses'] ?? 0, Icons.money_off),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.auto_awesome),
            title: Text('AI Daily Insight'),
            subtitle: Text('Ask AI to explain today’s sales, stock, dues and milk collection.'),
            trailing: Icon(Icons.chevron_right),
          ),
        ),
      ],
    ),
  );
}
