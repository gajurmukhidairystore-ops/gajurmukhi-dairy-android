import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/business_provider.dart';
import '../../services/delivery_route_service.dart';
import '../../services/location_service.dart';
import '../../services/mobile_cloud_service.dart';
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
  final routePosition = TextEditingController();
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
      final row = await widget.provider.createOrder(customerName: customer.text, phone: phone.text, itemsJson: jsonEncode([{'summary': summary.text.trim()}]), total: amount, deliveryAt: deliveryAt, reminderAt: reminderAt, reminderEnabled: reminderEnabled, note: note.text, routePosition: int.tryParse(routePosition.text.trim()));
      if (reminderEnabled) await notifications.scheduleOrderReminder(orderId: '${row['id']}', customerName: '${row['customer_name']}', reminderAt: reminderAt, orderSummary: 'Order ${row['order_no']} · NPR ${amount.toStringAsFixed(2)}');
      customer.clear(); phone.clear(); summary.clear(); total.clear(); note.clear(); routePosition.clear();
      if (mounted) { setState(() {}); _notice('Order ${row['order_no']} saved'); }
    } catch (error) {
      _notice('Could not save order: $error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _changeStatus(Map<String, Object?> order, String status) async {
    try {
      await widget.provider.updateOrderStatus('${order['id']}', status, role: widget.role);
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
        final sessionId = '${order['tracking_session_id'] ?? ''}'.trim();
        if (sessionId.isNotEmpty) await MobileCloudService().updateTrackingLocation(id: sessionId, latitude: position.latitude, longitude: position.longitude, accuracyMeters: position.accuracy);
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

  Future<void> _createSecureTrackingLink(Map<String, Object?> order) async {
    if (widget.role != 'admin') { _notice('Only Admin can issue a secure tracking link.'); return; }
    try {
      final result = await widget.provider.createSecureTrackingLink(orderId: '${order['id']}');
      final url = '${result['tracking_url'] ?? ''}'; if (url.isNotEmpty) await Clipboard.setData(ClipboardData(text: url));
      _notice('Secure tracking link created and copied.');
    } catch (error) { _notice('Could not create secure tracking link: $error'); }
  }
  Future<void> _setSecureTrackingStatus(Map<String, Object?> order, String status) async {
    if (widget.role != 'admin') { _notice('Only Admin can change tracking access.'); return; }
    try { await widget.provider.setSecureTrackingStatus(orderId: '${order['id']}', status: status); _notice('Tracking access changed to $status.'); } catch (error) { _notice('Could not update tracking access: $error'); }
  }
  Future<void> _copyTrackingLink(Map<String, Object?> order) async {
    final url = '${order['tracking_url'] ?? ''}'.trim(); if (url.isEmpty) { _notice('Create a secure tracking link first.'); return; }
    await Clipboard.setData(ClipboardData(text: url)); _notice('Secure tracking link copied.');
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

  Future<void> _openRouteInMaps(Map<String, Object?> order) async {
    final latitude = (order['destination_latitude'] as num?)?.toDouble();
    final longitude = (order['destination_longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      _notice('Capture the customer GPS location before opening the route.');
      return;
    }
    final route = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving');
    if (!await launchUrl(route, mode: LaunchMode.externalApplication)) _notice('Could not open Google Maps.');
  }

  Future<void> _recordHandover(Map<String, Object?> order, {required bool delivered}) async {
    if (!RolePermissions.canRecordDeliveryOutcome(widget.role)) {
      _notice('Your role cannot record delivery outcomes.');
      return;
    }
    if (!DeliveryRouteService.canConfirmHandover(status: '${order['status'] ?? ''}', arrivalUnlocked: order['call_unlocked'] == 1)) {
      _notice('Confirm handover after the delivery agent reaches the customer location and call unlocks.');
      return;
    }
    final reason = TextEditingController(text: delivered ? '' : '${order['missing_goods_note'] ?? ''}');
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(delivered ? 'Confirm goods delivered?' : 'Goods not delivered / missing?'),
      content: delivered ? const Text('This completes the delivery stop and cancels its pending order reminder.') : TextField(controller: reason, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Missing goods or reason', hintText: 'Milk not handed over, customer unavailable, item missing')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(delivered ? 'Confirm delivered' : 'Save reminder'))],
    ));
    if (confirmed != true) { reason.dispose(); return; }
    try {
      await widget.provider.recordDeliveryOutcome(orderId: '${order['id']}', delivered: delivered, missingGoodsNote: reason.text);
      if (delivered) {
        await notifications.cancelOrderReminder('${order['id']}');
        await _stopTracking();
        _notice('Stop completed and reminder cancelled.');
      } else {
        final reminderText = DeliveryRouteService.missingGoodsReminder(customerName: '${order['customer_name']}', items: '${order['items_json']}', reason: reason.text);
        await notifications.scheduleOrderReminder(orderId: '${order['id']}', customerName: '${order['customer_name']}', reminderAt: DateTime.now().add(const Duration(minutes: 20)), orderSummary: reminderText, status: 'DELIVERY_ATTEMPTED');
        _notice('Not-delivered reminder scheduled for 20 minutes from now.');
      }
    } catch (error) {
      _notice('Could not record handover: $error');
    } finally {
      reason.dispose();
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
  Widget build(BuildContext context) {
    final routeOrders = DeliveryRouteService.orderedStops(widget.provider.orders, agentId: widget.role == 'collector' ? widget.currentUserId : null);
    return ListView(padding: const EdgeInsets.all(16), children: [
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
          TextField(controller: routePosition, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Route stop number (optional)', hintText: '1 for first house, 2 for second house')),
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
        if (routeOrders.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No active delivery stops.'))),
        ...routeOrders.map((order) {
          final isTracking = trackingOrderId == '${order['id']}';
          final isAssigned = '${order['delivery_agent_id'] ?? ''}'.trim().isNotEmpty;
          final callReady = order['call_unlocked'] == 1;
          return Card(child: ListTile(
            leading: Icon(callReady ? Icons.phone_in_talk : (isAssigned ? Icons.local_shipping : Icons.receipt_long), color: callReady ? Colors.green : null),
            title: Text('Stop ${order['route_position'] ?? '-'} · ${order['order_no']} · ${order['customer_name']}'),
            subtitle: Text('NPR ${order['total']} · ${order['status']} · Result: ${order['delivery_result'] ?? 'PENDING'}\nDelivery: ${order['delivery_at'] ?? 'Not scheduled'}\nAgent: ${isAssigned ? '${order['delivery_agent_name']} (${order['delivery_agent_phone'] ?? 'no phone'})' : 'Not assigned'}\nLocation: ${_locationText(order)}${'${order['missing_goods_note'] ?? ''}'.trim().isEmpty ? '' : '\nPending: ${order['missing_goods_note']}'}${'${order['tracking_url'] ?? ''}'.trim().isEmpty ? '' : '\nBrowser tracking: ${order['tracking_status'] ?? 'ACTIVE'} · expires ${order['tracking_expires_at'] ?? 'configured time'}'}'),
            isThreeLine: false,
            trailing: PopupMenuButton<String>(onSelected: (value) {
              if (value == 'assign') _assignDeliveryAgent(order);
              if (value == 'track') _startTracking(order);
              if (value == 'stop') _stopTracking();
              if (value == 'secure_create') _createSecureTrackingLink(order);
              if (value == 'secure_copy') _copyTrackingLink(order);
              if (value == 'secure_block') _setSecureTrackingStatus(order, 'BLOCKED');
              if (value == 'secure_unblock') _setSecureTrackingStatus(order, 'ACTIVE');
              if (value == 'secure_pause') _setSecureTrackingStatus(order, 'PAUSED');
              if (value == 'secure_resume') _setSecureTrackingStatus(order, 'ACTIVE');
              if (value == 'secure_end') _setSecureTrackingStatus(order, 'ENDED');
              if (value == 'call') _callCustomer(order);
              if (value == 'maps') _openRouteInMaps(order);
              if (value == 'handover:delivered') _recordHandover(order, delivered: true);
              if (value == 'handover:not_delivered') _recordHandover(order, delivered: false);
              if (value == 'status:CONFIRMED') _changeStatus(order, value.substring(7));
            }, itemBuilder: (_) => [
              if (RolePermissions.canAssignDelivery(widget.role)) const PopupMenuItem(value: 'assign', child: Text('Assign / change agent')),
              if (RolePermissions.canStartDeliveryTracking(widget.role) && isAssigned && '${order['delivery_agent_id'] ?? ''}' == widget.currentUserId.trim() && !isTracking) const PopupMenuItem(value: 'track', child: Text('Start live tracking')),
              if (isTracking) const PopupMenuItem(value: 'stop', child: Text('Stop live tracking')),
              if (widget.role == 'admin' && '${order['tracking_url'] ?? ''}'.trim().isEmpty) const PopupMenuItem(value: 'secure_create', child: Text('Create secure browser tracking link')),
              if (widget.role == 'admin' && '${order['tracking_url'] ?? ''}'.trim().isNotEmpty) ...[
                const PopupMenuItem(value: 'secure_copy', child: Text('Copy secure tracking link')),
                if ('${order['tracking_status'] ?? 'NOT_STARTED'}' == 'BLOCKED') const PopupMenuItem(value: 'secure_unblock', child: Text('Unblock tracking link')) else const PopupMenuItem(value: 'secure_block', child: Text('Block tracking link now')),
                if ('${order['tracking_status'] ?? ''}' == 'PAUSED') const PopupMenuItem(value: 'secure_resume', child: Text('Resume browser tracking')) else const PopupMenuItem(value: 'secure_pause', child: Text('Pause browser tracking')),
                if ('${order['tracking_status'] ?? ''}' != 'ENDED') const PopupMenuItem(value: 'secure_end', child: Text('End browser tracking')),
              ],
              const PopupMenuItem(value: 'maps', child: Text('Open this stop in Google Maps')),
              if (RolePermissions.canCallCustomer(widget.role)) PopupMenuItem(value: 'call', child: Text(callReady ? 'Call customer (within 100 m)' : 'Call locked until arrival')),
              if (RolePermissions.canRecordDeliveryOutcome(widget.role)) const PopupMenuItem(value: 'handover:delivered', child: Text('Confirm delivered / goods handed over')),
              if (RolePermissions.canRecordDeliveryOutcome(widget.role)) const PopupMenuItem(value: 'handover:not_delivered', child: Text('Not delivered / missing goods reminder')),
              if (RolePermissions.canMarkOrderReady(widget.role)) const PopupMenuItem(value: 'status:READY', child: Text('Mark order ready for Collector')),
              if (widget.role == 'collector') const PopupMenuItem(value: 'status:DELIVERED', child: Text('Done · delivery complete')),
              const PopupMenuItem(value: 'status:CONFIRMED', child: Text('Confirmed')),
              const PopupMenuItem(value: 'status:OUT_FOR_DELIVERY', child: Text('Out for delivery')),
              const PopupMenuItem(value: 'status:DELIVERED', child: Text('Delivered')),
              const PopupMenuItem(value: 'status:CANCELLED', child: Text('Cancelled')),
            ]),
          ));
        }),
      ]);
  }

  @override
  void dispose() { unawaited(deliveryTracking.stop()); customer.dispose(); phone.dispose(); summary.dispose(); total.dispose(); note.dispose(); routePosition.dispose(); super.dispose(); }
}
