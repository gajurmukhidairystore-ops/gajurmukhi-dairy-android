import 'dart:convert';

import 'package:flutter/material.dart';
import '../../providers/business_provider.dart';
import '../../services/order_notification_service.dart';

class OrdersScreen extends StatefulWidget {
  final BusinessProvider provider;
  final String role;
  const OrdersScreen(this.provider, {super.key, this.role = 'admin'});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final customer = TextEditingController();
  final phone = TextEditingController();
  final summary = TextEditingController();
  final total = TextEditingController();
  final note = TextEditingController();
  final notifications = OrderNotificationService();
  DateTime deliveryAt = DateTime.now().add(const Duration(hours: 1));
  DateTime reminderAt = DateTime.now().add(const Duration(minutes: 30));
  bool reminderEnabled = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    notifications.init();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: initial);
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    final amount = double.tryParse(total.text.trim());
    if (customer.text.trim().isEmpty || summary.text.trim().isEmpty || amount == null || amount <= 0) {
      _notice('Enter customer name, order items/summary, and a valid total.');
      return;
    }
    setState(() => busy = true);
    try {
      final row = await widget.provider.createOrder(customerName: customer.text, phone: phone.text, itemsJson: jsonEncode([{'summary': summary.text.trim()}]), total: amount, deliveryAt: deliveryAt, reminderAt: reminderAt, reminderEnabled: reminderEnabled, note: note.text);
      if (reminderEnabled) await notifications.scheduleOrderReminder(orderId: '${row['id']}', customerName: '${row['customer_name']}', reminderAt: reminderAt, orderSummary: 'Order ${row['order_no']} · NPR ${amount.toStringAsFixed(2)}');
      customer.clear(); phone.clear(); summary.clear(); total.clear(); note.clear();
      if (mounted) { setState(() {}); _notice('Order ${row['order_no']} saved'); }
    } catch (error) {
      _notice('Could not save order: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _changeStatus(Map<String, Object?> order, String status) async {
    final id = '${order['id']}';
    await widget.provider.updateOrderStatus(id, status);
    if (status == 'DELIVERED' || status == 'CANCELLED') await notifications.cancelOrderReminder(id);
    if (mounted) setState(() {});
  }

  void _notice(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _format(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${TimeOfDay.fromDateTime(value).format(context)}';

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Orders & Reminders', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text('Take orders offline and receive a reminder before delivery. Role: ${widget.role}'),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: customer, decoration: const InputDecoration(labelText: 'Customer name')),
          const SizedBox(height: 8),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone / WhatsApp (optional)')),
          const SizedBox(height: 8),
          TextField(controller: summary, maxLines: 2, decoration: const InputDecoration(labelText: 'Order items or summary')),
          const SizedBox(height: 8),
          TextField(controller: total, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Order total (NPR)')),
          const SizedBox(height: 8),
          TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 8),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event), title: const Text('Delivery date and time'), subtitle: Text(_format(deliveryAt)), trailing: IconButton(icon: const Icon(Icons.edit_calendar), onPressed: () async { final picked = await _pickDateTime(deliveryAt); if (picked != null) setState(() => deliveryAt = picked); })),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Reminder notification'), subtitle: Text(reminderEnabled ? 'Reminder at ${_format(reminderAt)}' : 'No reminder will be scheduled'), value: reminderEnabled, onChanged: (value) async { setState(() => reminderEnabled = value); if (value) { final picked = await _pickDateTime(reminderAt); if (picked != null) setState(() => reminderAt = picked); } }),
          FilledButton.icon(onPressed: busy ? null : _save, icon: const Icon(Icons.add_task), label: Text(busy ? 'Saving…' : 'Save order and reminder')),
        ]))),
        const SizedBox(height: 12),
        Text('Saved orders', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        if (widget.provider.orders.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No orders saved yet.'))),
        ...widget.provider.orders.map((order) => Card(child: ListTile(leading: const Icon(Icons.receipt_long), title: Text('${order['order_no']} · ${order['customer_name']}'), subtitle: Text('NPR ${order['total']} · ${order['status']}\nDelivery: ${order['delivery_at'] ?? 'Not scheduled'}'), isThreeLine: true, trailing: PopupMenuButton<String>(onSelected: (value) => _changeStatus(order, value), itemBuilder: (_) => const [PopupMenuItem(value: 'CONFIRMED', child: Text('Confirmed')), PopupMenuItem(value: 'OUT_FOR_DELIVERY', child: Text('Out for delivery')), PopupMenuItem(value: 'DELIVERED', child: Text('Delivered')), PopupMenuItem(value: 'CANCELLED', child: Text('Cancelled'))])))),
      ]);

  @override
  void dispose() { customer.dispose(); phone.dispose(); summary.dispose(); total.dispose(); note.dispose(); super.dispose(); }
}
