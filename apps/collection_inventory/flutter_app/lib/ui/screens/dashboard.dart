import 'package:flutter/material.dart';

import '../../providers/business_provider.dart';
import '../../services/nepali_date_service.dart';

bool canSubmitPayment({required String? customerId, required String amountText, required bool saving}) {
  final amount = double.tryParse(amountText) ?? 0;
  return customerId != null && customerId.isNotEmpty && amount > 0 && !saving;
}

class DashboardScreen extends StatefulWidget {
  final BusinessProvider p;
  final ValueChanged<int>? onNavigate;
  const DashboardScreen(this.p, {super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final search = TextEditingController();
  String filter = 'All';

  BusinessProvider get p => widget.p;
  num get milk => p.totals['milkLitres'] ?? 0;
  num get amount => p.totals['sales'] ?? 0;
  num get received => p.totals['collection'] ?? 0;
  num get due => p.totals['due'] ?? 0;
  num get milkInventory => p.products.where((product) => '${product['name'] ?? ''}'.toLowerCase() == 'milk 1 ltr').fold<num>(0, (sum, product) => sum + ((product['stock'] as num?) ?? 0));

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String monthLabel(DateTime date) => NepaliDateService.fromAd(date);

  void open(int index) => widget.onNavigate?.call(index);

  Future<void> showPayDialog() async {
    final pageContext = context;
    final messenger = ScaffoldMessenger.maybeOf(pageContext);
    final amountController = TextEditingController();
    String? customerId;
    var saving = false;
    try {
      await showDialog<void>(
        context: pageContext,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Record payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: customerId,
                  hint: const Text('Select customer'),
                  items: p.customers
                      .map((customer) => DropdownMenuItem<String>(
                            value: customer['id']?.toString(),
                            child: Text('${customer['name']}'),
                          ))
                      .toList(),
                  onChanged: (value) => setDialogState(() => customerId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (NPR)'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final value = double.tryParse(amountController.text.trim()) ?? 0;
                        if (!canSubmitPayment(customerId: customerId, amountText: amountController.text, saving: saving)) return;
                        setDialogState(() => saving = true);
                        try {
                          await p.recordPayment(customerId, value, 'CASH', 'Payment from Milk Khata home');
                          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                        } catch (error) {
                          if (dialogContext.mounted) setDialogState(() => saving = false);
                          messenger?.showSnackBar(SnackBar(content: Text('Could not save payment: $error')));
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save payment'),
              ),
            ],
          ),
        ),
      );
    } finally {
      amountController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final customers = p.customers.where((customer) {
      final name = '${customer['name'] ?? ''}'.toLowerCase();
      final phone = '${customer['phone'] ?? ''}'.toLowerCase();
      final matchesSearch = query.isEmpty || name.contains(query) || phone.contains(query);
      final matchesFilter = filter == 'All' || filter == 'Due' && ((customer['balance'] as num?) ?? 0) > 0;
      return matchesSearch && matchesFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: p.refresh,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                color: const Color(0xff1976e8),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset('assets/gajurmukhi-app-logo.png', width: 128, height: 64, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Gajurmukhi Dairy',
                          style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(onPressed: p.refresh, color: Colors.white, icon: const Icon(Icons.cloud_done_outlined)),
                      PopupMenuButton<String>(
                        iconColor: Colors.white,
                        onSelected: (value) {
                          if (value == 'stock') open(3);
                          if (value == 'ai') open(6);
                          if (value == 'expenses') open(7);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'stock', child: Text('Stock & products')),
                          PopupMenuItem(value: 'ai', child: Text('AI assistant')),
                          PopupMenuItem(value: 'expenses', child: Text('Expenses & payment out')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -1),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xfffbfbff),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_left, color: Color(0xff176acb))),
                          Text(monthLabel(DateTime.now()), style: const TextStyle(fontSize: 21, color: Color(0xff176acb), fontWeight: FontWeight.w700)),
                          IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right, color: Color(0xff176acb))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _SummaryCard(milk: milk, amount: amount, due: due, received: received),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 0,
                        color: const Color(0xffeaf7f0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.local_drink_outlined, color: Color(0xff268b58))),
                          title: const Text('Dairy inventory', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('Milk received from farmer collections'),
                          trailing: Text('${milkInventory.toStringAsFixed(1)} L', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xff268b58))),
                          onTap: () => open(3),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _QuickAction(icon: Icons.chat_outlined, label: 'Share', color: const Color(0xffd7f5eb), onTap: () => open(1))),
                          const SizedBox(width: 8),
                          Expanded(child: _QuickAction(icon: Icons.payments_outlined, label: 'Pay', color: const Color(0xffdcecff), onTap: showPayDialog)),
                          const SizedBox(width: 8),
                          Expanded(child: _QuickAction(icon: Icons.history, label: 'History', color: const Color(0xfff1dcf5), onTap: () => open(2))),
                          const SizedBox(width: 8),
                          Expanded(child: _QuickAction(icon: Icons.calendar_month_outlined, label: 'Bulk Entry', color: const Color(0xffdff2ef), onTap: () => open(4))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search entries...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _FilterChip(label: 'All', selected: filter == 'All', onTap: () => setState(() => filter = 'All'))),
                          Expanded(child: _FilterChip(label: 'Buy Milk', selected: filter == 'Buy Milk', onTap: () => open(4))),
                          Expanded(child: _FilterChip(label: 'Sell Milk', selected: filter == 'Sell Milk', onTap: () => open(1))),
                          Expanded(child: _FilterChip(label: 'Due', selected: filter == 'Due', onTap: () => setState(() => filter = 'Due'))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(alignment: Alignment.centerLeft, child: Text(monthLabel(DateTime.now()), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                      const SizedBox(height: 8),
                      if (customers.isEmpty)
                        const Padding(padding: EdgeInsets.all(24), child: Text('No customer entries yet. Add a customer to start the ledger.'))
                      else
                        ...customers.map((customer) => _CustomerRow(customer: customer, onAdd: () => open(2))),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton.extended(
              onPressed: () => open(2),
              backgroundColor: const Color(0xff1476ed),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Entry'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final num milk;
  final num amount;
  final num due;
  final num received;
  const _SummaryCard({required this.milk, required this.amount, required this.due, required this.received});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  _Metric(label: 'Milk', value: '${milk.toStringAsFixed(1)} L', color: const Color(0xff20252c)),
                  _Metric(label: 'Amount', value: 'NPR${amount.toStringAsFixed(0)}', color: const Color(0xff176acb)),
                  _Metric(label: 'Due', value: 'NPR${due.toStringAsFixed(0)}', color: const Color(0xffd64d4d)),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(child: Text('Received\nNPR${received.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xff4ca55b), fontSize: 16, height: 1.35))),
                  DecoratedBox(
                    decoration: BoxDecoration(color: const Color(0xffe4f2ff), borderRadius: BorderRadius.circular(24)),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8), child: Text('Outstanding: NPR${due.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xff176acb), fontSize: 13))),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)), const SizedBox(height: 5), Text(value, style: TextStyle(color: color, fontSize: 21, fontWeight: FontWeight.w700))]),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), child: Column(children: [Icon(icon, size: 21), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 12))])),
        ),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: selected ? Colors.white : const Color(0xfff0f0f3), borderRadius: BorderRadius.circular(10), boxShadow: selected ? const [BoxShadow(color: Colors.black12, blurRadius: 3)] : null),
          child: Center(child: Text(label, style: TextStyle(color: selected ? const Color(0xff176acb) : Colors.black54, fontWeight: selected ? FontWeight.w700 : FontWeight.w400))),
        ),
      );
}

class _CustomerRow extends StatelessWidget {
  final Map<String, Object?> customer;
  final VoidCallback onAdd;
  const _CustomerRow({required this.customer, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final name = '${customer['name'] ?? 'Customer'}';
    final balance = (customer['balance'] as num?) ?? 0;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xffe3e3e8)))),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: const Color(0xff1976e8), foregroundColor: Colors.white, child: Text(initial)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), Text('${customer['phone'] ?? 'No phone'}', style: const TextStyle(color: Colors.black45, fontSize: 12))])),
          Text(balance > 0 ? 'Due: NPR${balance.toStringAsFixed(0)}' : 'Due: NPR0', style: TextStyle(color: balance > 0 ? const Color(0xffd64d4d) : const Color(0xff4ca55b), fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          TextButton(onPressed: onAdd, child: const Text('+ Add')),
        ],
      ),
    );
  }
}
