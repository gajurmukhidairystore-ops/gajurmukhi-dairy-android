import 'package:flutter/material.dart';
import '../../providers/business_provider.dart';
import '../../services/whatsapp_service.dart';

class CustomersScreen extends StatefulWidget {
  final BusinessProvider p;
  const CustomersScreen(this.p, {super.key});
  @override State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  Future<void> _record(BuildContext context, Map<String, Object?> customer, {required bool advance}) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    String method = 'CASH';
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text(advance ? 'Record advance' : 'Record payment'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (NPR)')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: method, decoration: const InputDecoration(labelText: 'Method'), items: const [DropdownMenuItem(value: 'CASH', child: Text('Cash')), DropdownMenuItem(value: 'QR', child: Text('QR')), DropdownMenuItem(value: 'BANK', child: Text('Bank'))], onChanged: (v) => setDialogState(() => method = v ?? 'CASH')),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    )));
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (ok == true && value > 0) {
      final id = '${customer['id']}';
      if (advance) {
        await widget.p.recordAdvance(id, value, method, note.text.trim().isEmpty ? 'Advance' : note.text.trim());
      } else {
        await widget.p.recordPayment(id, value, method, note.text.trim().isEmpty ? 'Customer payment' : note.text.trim());
      }
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Ledger updated')));
    }
  }

  Future<void> _remind(BuildContext context, Map<String, Object?> customer) async {
    final amount = (customer['balance'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This customer has no outstanding balance'))); return; }
    final name = '${customer['name'] ?? 'Customer'}';
    final message = 'Hello $name, this is a friendly reminder that your outstanding balance is NPR ${amount.toStringAsFixed(2)}. Thank you — Gajurmukhi Customer.';
    try {
      await widget.p.createCreditReminder(customerId: '${customer['id']}', amount: amount, channel: 'WHATSAPP', message: message);
      final phone = '${customer['phone'] ?? ''}'.trim();
      if (phone.isEmpty) { if (!mounted) return; ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Reminder saved, but this customer has no phone number'))); return; }
      await WhatsAppService().openMessage(phone, message);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Could not create reminder: $error')));
    }
  }

  Future<void> _statement(BuildContext context, Map<String, Object?> customer) async {
    final entries = await widget.p.customerLedger('${customer['id']}');
    if (!context.mounted) return;
    await showDialog<void>(context: context, builder: (_) => AlertDialog(
      title: Text('${customer['name']} — ledger'),
      content: SizedBox(width: 420, child: entries.isEmpty ? const Text('No ledger entries yet.') : ListView.builder(shrinkWrap: true, itemCount: entries.length, itemBuilder: (_, i) { final e = entries[i]; return ListTile(dense: true, title: Text('${e['type']} · NPR ${e['amount']}'), subtitle: Text('${e['note'] ?? ''}\n${e['created_at'] ?? ''}')); })),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ));
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
    Row(children: [const Expanded(child: Text('Customer ledger', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: () => _addCustomer(context), icon: const Icon(Icons.person_add), label: const Text('Add customer'))]),
    const SizedBox(height: 12),
    ...widget.p.customers.map((c) => Card(child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text('${c['name']}'),
      subtitle: Text('${c['phone'] ?? ''}\nOutstanding: NPR ${c['balance'] ?? 0}'),
      isThreeLine: true,
      onTap: () => _statement(context, c),
      trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'payment') _record(context, c, advance: false); if (v == 'advance') _record(context, c, advance: true); if (v == 'statement') _statement(context, c); if (v == 'remind') _remind(context, c); }, itemBuilder: (_) => const [PopupMenuItem(value: 'payment', child: Text('Record payment')), PopupMenuItem(value: 'advance', child: Text('Record advance')), PopupMenuItem(value: 'statement', child: Text('View statement')), PopupMenuItem(value: 'remind', child: Text('Send credit reminder'))]),
    )))
  ]);

  Future<void> _addCustomer(BuildContext context) async {
    final name = TextEditingController(); final phone = TextEditingController(); final address = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Add customer'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')), TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')), TextField(controller: address, decoration: const InputDecoration(labelText: 'Address'))]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))]));
    if (ok == true && name.text.trim().isNotEmpty) await widget.p.addCustomer(name.text.trim(), phone.text.trim(), address.text.trim());
  }
}
