import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/business_provider.dart';
import '../../services/location_service.dart';
import '../../services/order_notification_service.dart';
import '../../services/role_permissions.dart';

class OrdersScreen extends StatefulWidget {
  final BusinessProvider provider;
  final String role;
  final String currentUserId;
  const OrdersScreen(this.provider, {super.key, this.role = 'admin', this.currentUserId = ''});

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
  final deliveryTracking = DeliveryTrackingService();
  DateTime deliveryAt = DateTime.now().add(const Duration(hours: 1));
  DateTime reminderAt = DateTime.now().add(const Duration(minutes: 30));
  bool reminderEnabled = true;
  bool busy = false;
  String? trackingOrderId;

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
    try {
      await widget.provider.updateOrderStatus('${order['id']}', status);
      if (status == 'DELIVERED' || status == 'CANCELLED') await notifications.cancelOrderReminder('${order['id']}');
      if (status == 'DELIVERED' || status == 'CANCELLED') await _stopTracking();
    } catch (error) {
      _notice('Could not update order: $error');
    }
  }

  Future<void> _assignDeliveryAgent(Map<String, Object?> order) async {
    if (!RolePermissions.canAssignDelivery(widget.role)) {
      _notice('Only Admin or Store can assign a delivery agent.');
      return;
    }
    final agentId = TextEditingController(text: '${order['delivery_agent_id'] ?? ''}');
    final agentName = TextEditingController(text: '${order['delivery_agent_name'] ?? ''}');
    final agentPhone = TextEditingController(text: '${order['delivery_agent_phone'] ?? ''}');
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Assign delivery agent'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: agentId, decoration: const InputDecoration(labelText: 'Agent ID / username')),
        TextField(controller: agentName, decoration: const InputDecoration(labelText: 'Agent name')),
        TextField(controller: agentPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Agent phone')),
        const SizedBox(height: 8),
        const Text('The order must have a customer GPS location before it can be assigned for tracking.', style: TextStyle(fontSize: 12)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Assign'))],
    ));
    if (ok != true) return;
    try {
      await widget.provider.assignDeliveryAgent(orderId: '${order['id']}', agentId: agentId.text, agentName: agentName.text, agentPhone: agentPhone.text);
      _notice('Delivery agent assigned.');
    } catch (error) {
      _notice('Could not assign delivery agent: $error');
    } finally {
      agentId.dispose(); agentName.dispose(); agentPhone.dispose();
    }
  }

  Future<void> _startTracking(Map<String, Object?> order) async {
    if (!RolePermissions.canStartDeliveryTracking(widget.role)) {
      _notice('Only the assigned Collector device can transmit live GPS.');
      return;
    }
    final orderId = '${order['id']}';
    final agentId = '${order['delivery_agent_id'] ?? ''}'.trim();
    if (agentId != widget.currentUserId.trim()) {
      _notice('This order is assigned to another delivery agent.');
      return;
    }
    final destinationLatitude = (order['destination_latitude'] as num?)?.toDouble();
    final destinationLongitude = (order['destination_longitude'] as num?)?.toDouble();
    if (agentId.isEmpty || destinationLatitude == null || destinationLongitude == null) {
      _notice('Assign an agent after capturing the customer GPS location first.');
      return;
    }
    await _stopTracking();
    final started = await deliveryTracking.start(destinationLatitude: destinationLatitude, destinationLongitude: destinationLongitude, onUpdate: (position, _) async {
      try {
        await widget.provider.recordDriverLocation(orderId: orderId, agentId: agentId, latitude: position.latitude, longitude: position.longitude, accuracy: position.accuracy);
      } catch (error) {
        _notice('Location update failed: $error');
      }
    });
    if (!started) {
      _notice('Enable GPS and grant location permission to start tracking.');
      return;
    }
    if (mounted) setState(() => trackingOrderId = orderId);
    try {
      if ('${order['status']}' == 'PENDING' || '${order['status']}' == 'CONFIRMED') await widget.provider.updateOrderStatus(orderId, 'OUT_FOR_DELIVERY');
      _notice('Live tracking started. Updates are sent every 30 seconds, or every 15 seconds within 1 km.');
    } catch (error) {
      _notice('Tracking started, but status update failed: $error');
    }
  }

  Future<void> _stopTracking() async {
    await deliveryTracking.stop();
    if (mounted && trackingOrderId != null) setState(() => trackingOrderId = null);
  }

  Future<void> _callCustomer(Map<String, Object?> order) async {
    if (!RolePermissions.canCallCustomer(widget.role)) {
      _notice('Your role cannot call customers from delivery tracking.');
      return;
    }
    if (order['call_unlocked'] != 1) {
      _notice('Call unlocks only after the driver is within 100 metres of the customer.');
      return;
    }
    final phoneNumber = '${order['phone'] ?? ''}'.trim();
    if (phoneNumber.isEmpty) {
      _notice('This order has no customer phone number.');
      return;
    }
    try {
      await widget.provider.markDeliveryCallAttempted('${order['id']}');
      final opened = await launchUrl(Uri(scheme: 'tel', path: phoneNumber));
      if (!opened) _notice('Could not open the phone dialer.');
    } catch (error) {
      _notice('Call is not available: $error');
    }
  }

  void _notice(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _format(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${TimeOfDay.fromDateTime(value).format(context)}';

  String _locationText(Map<String, Object?> order) {
    final distance = (order['driver_distance_meters'] as num?)?.toDouble();
    if (distance == null) return 'No driver location yet';
    final interval = order['tracking_interval_seconds'] ?? 30;
    final arrival = order['call_unlocked'] == 1 ? 'Call unlocked' : 'Call locked until 100 m';
    return '${formatDistanceMeters(distance)} away · next update ${interval}s · $arrival';
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Orders & Delivery', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text('Take orders offline, schedule reminders, assign delivery, and track arrival. Role: ${widget.role}'),
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
        ...widget.provider.orders.map((order) {
          final isTracking = trackingOrderId == '${order['id']}';
          final isAssigned = '${order['delivery_agent_id'] ?? ''}'.trim().isNotEmpty;
          final callReady = order['call_unlocked'] == 1;
          return Card(child: ListTile(
            leading: Icon(callReady ? Icons.phone_in_talk : (isAssigned ? Icons.local_shipping : Icons.receipt_long), color: callReady ? Colors.green : null),
            title: Text('${order['order_no']} · ${order['customer_name']}'),
            subtitle: Text('NPR ${order['total']} · ${order['status']}\nDelivery: ${order['delivery_at'] ?? 'Not scheduled'}\nAgent: ${isAssigned ? '${order['delivery_agent_name']} (${order['delivery_agent_phone'] ?? 'no phone'})' : 'Not assigned'}\nLocation: ${_locationText(order)}'),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(onSelected: (value) {
              if (value == 'assign') _assignDeliveryAgent(order);
              if (value == 'track') _startTracking(order);
              if (value == 'stop') _stopTracking();
              if (value == 'call') _callCustomer(order);
              if (value.startsWith('status:')) _changeStatus(order, value.substring(7));
            }, itemBuilder: (_) => [
              if (RolePermissions.canAssignDelivery(widget.role)) const PopupMenuItem(value: 'assign', child: Text('Assign / change agent')),
              if (RolePermissions.canStartDeliveryTracking(widget.role) && isAssigned && '${order['delivery_agent_id'] ?? ''}' == widget.currentUserId.trim() && !isTracking) const PopupMenuItem(value: 'track', child: Text('Start live tracking')),
              if (isTracking) const PopupMenuItem(value: 'stop', child: Text('Stop live tracking')),
              if (RolePermissions.canCallCustomer(widget.role)) PopupMenuItem(value: 'call', child: Text(callReady ? 'Call customer (within 100 m)' : 'Call locked until arrival')),
              const PopupMenuItem(value: 'status:CONFIRMED', child: Text('Confirmed')),
              const PopupMenuItem(value: 'status:OUT_FOR_DELIVERY', child: Text('Out for delivery')),
              const PopupMenuItem(value: 'status:DELIVERED', child: Text('Delivered')),
              const PopupMenuItem(value: 'status:CANCELLED', child: Text('Cancelled')),
            ]),
          ));
        }),
      ]);

  @override
  void dispose() { unawaited(deliveryTracking.stop()); customer.dispose(); phone.dispose(); summary.dispose(); total.dispose(); note.dispose(); super.dispose(); }
}
