import 'package:flutter/material.dart';

import '../../providers/business_provider.dart';
import '../../services/ai_command_service.dart';

class LoansScreen extends StatefulWidget {
  final BusinessProvider provider;
  const LoansScreen(this.provider, {super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  String _money(Object? value) => AppSettingsService.money(value is num ? value : double.tryParse('$value') ?? 0);

  Future<void> _addLoan() async {
    final name = TextEditingController();
    final lender = TextEditingController();
    final principal = TextEditingController();
    final annualRate = TextEditingController(text: '0');
    final note = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Add loan account'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Loan name / account')),
        const SizedBox(height: 8),
        TextField(controller: lender, decoration: const InputDecoration(labelText: 'Bank, cooperative, or lender')),
        const SizedBox(height: 8),
        TextField(controller: principal, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Opening principal (${AppSettingsService.currencyCode.value})')),
        const SizedBox(height: 8),
        TextField(controller: annualRate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Annual interest rate (%)', helperText: 'Interest is calculated daily on the reducing principal.')),
        const SizedBox(height: 8),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save loan'))],
    ));
    if (accepted == true) {
      try {
        await widget.provider.addLoan(name: name.text, lender: lender.text, principal: double.tryParse(principal.text) ?? 0, annualInterestRate: double.tryParse(annualRate.text) ?? -1, startDate: DateTime.now(), note: note.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan account added')));
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save loan: $error')));
      }
    }
    name.dispose(); lender.dispose(); principal.dispose(); annualRate.dispose(); note.dispose();
  }

  Future<void> _recordPayment(Map<String, Object?> loan) async {
    final snapshot = await widget.provider.loanSnapshot('${loan['id']}');
    if (!mounted) return;
    final amount = TextEditingController(text: '${snapshot['remaining_total']}');
    final note = TextEditingController(text: 'Daily loan repayment');
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('Record payment · ${loan['name']}'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Remaining total: ${_money(snapshot['remaining_total'])}'),
        Text('Principal: ${_money(snapshot['remaining_principal'])} · Interest due: ${_money(snapshot['outstanding_interest'])}', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Payment amount (${AppSettingsService.currencyCode.value})')),
        const SizedBox(height: 8),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Record payment'))],
    ));
    if (accepted == true) {
      try {
        await widget.provider.recordLoanPayment(loanId: '${loan['id']}', amount: double.tryParse(amount.text) ?? 0, note: note.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan payment recorded')));
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not record payment: $error')));
      }
    }
    amount.dispose(); note.dispose();
  }

  Future<void> _showStatement(Map<String, Object?> loan) async {
    final snapshot = await widget.provider.loanSnapshot('${loan['id']}');
    if (!mounted) return;
    final entries = (snapshot['statement'] as List).cast<Map<String, dynamic>>();
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('Loan statement · ${loan['name']}'),
      content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Paid today: ${_money(snapshot['today_paid'])}'),
        Text('Total paid: ${_money(snapshot['total_paid'])}'),
        Text('Remaining principal: ${_money(snapshot['remaining_principal'])}'),
        Text('Accrued interest: ${_money(snapshot['outstanding_interest'])}'),
        const Divider(),
        Flexible(child: entries.isEmpty ? const Text('No repayment entry yet.') : ListView.builder(shrinkWrap: true, itemCount: entries.length, itemBuilder: (_, index) {
          final entry = entries[index];
          return ListTile(dense: true, title: Text('${entry['date'].toString().substring(0, 10)} · Paid ${_money(entry['amount'])}'), subtitle: Text('Interest ${_money(entry['interest_paid'])} · Principal ${_money(entry['principal_paid'])} · Remaining ${_money(entry['remaining_principal'])}\n${entry['note']}'));
        })),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
    ));
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
    Row(children: [const Expanded(child: Text('Loan accounts', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: _addLoan, icon: const Icon(Icons.add_card), label: const Text('Add loan'))]),
    const Padding(padding: EdgeInsets.only(top: 8, bottom: 12), child: Text('Interest uses a transparent daily simple rate on the reducing principal. Each repayment pays accrued interest first, then reduces principal.')),
    if (widget.provider.loans.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No loan account has been added. Add a loan to track daily payments, interest, remaining balance, and its statement.'))),
    ...widget.provider.loans.map((loan) => FutureBuilder<Map<String, dynamic>>(
      future: widget.provider.loanSnapshot('${loan['id']}'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Card(child: ListTile(title: Text('${loan['name']}'), subtitle: const Text('Calculating loan balance…')));
        final balance = snapshot.data!;
        return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${loan['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${loan['lender']} · ${loan['annual_interest_rate']}% annual · Daily reducing interest'),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 8, children: [
            _Metric(label: 'Paid today', value: _money(balance['today_paid'])),
            _Metric(label: 'Total paid', value: _money(balance['total_paid'])),
            _Metric(label: 'Principal remaining', value: _money(balance['remaining_principal'])),
            _Metric(label: 'Interest due', value: _money(balance['outstanding_interest'])),
            _Metric(label: 'Total remaining', value: _money(balance['remaining_total'])),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [FilledButton.icon(onPressed: () => _recordPayment(loan), icon: const Icon(Icons.payments_outlined), label: const Text('Record daily payment')), OutlinedButton.icon(onPressed: () => _showStatement(loan), icon: const Icon(Icons.receipt_long), label: const Text('View statement'))]),
        ])));
      },
    )),
  ]);
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelMedium), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));
}
