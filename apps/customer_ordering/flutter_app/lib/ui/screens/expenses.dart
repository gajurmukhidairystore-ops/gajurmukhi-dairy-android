import 'package:flutter/material.dart';

import '../../providers/business_provider.dart';

class ExpensesScreen extends StatefulWidget {
  final BusinessProvider p;
  const ExpensesScreen(this.p, {super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final category = TextEditingController();
  final amount = TextEditingController();
  final note = TextEditingController();
  String method = 'CASH';

  @override
  void dispose() {
    category.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> saveExpense() async {
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (value <= 0) return;
    await widget.p.recordExpense(
      category.text.trim().isEmpty ? 'General expense' : category.text.trim(),
      value,
      method,
      note.text.trim(),
    );
    if (!mounted) return;
    category.clear();
    amount.clear();
    note.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment out recorded')));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final expenseTotal = widget.p.totals['expenses'] ?? 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Expenses & payment out', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Track business expenses and cash leaving the dairy counter.'),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xfffff4f5),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xffffdfe3), child: Icon(Icons.arrow_upward, color: Color(0xffc63f53))),
            title: const Text('Today’s expense'),
            subtitle: Text('Payment out · NPR ${expenseTotal.toStringAsFixed(2)}'),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(controller: category, decoration: const InputDecoration(labelText: 'Category', hintText: 'Transport, supplies, rent...')),
                const SizedBox(height: 12),
                TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (NPR)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Payment method'),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                    DropdownMenuItem(value: 'QR', child: Text('QR')),
                  ],
                  onChanged: (value) => setState(() => method = value ?? 'CASH'),
                ),
                const SizedBox(height: 12),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saveExpense, icon: const Icon(Icons.account_balance_wallet_outlined), label: const Text('Save payment out'))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
