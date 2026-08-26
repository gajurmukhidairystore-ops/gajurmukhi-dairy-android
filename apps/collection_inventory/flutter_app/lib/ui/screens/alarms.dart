import 'package:flutter/material.dart';
import '../../providers/business_provider.dart';
import '../../services/alarm_service.dart';

class AlarmsScreen extends StatefulWidget {
  final BusinessProvider p;
  final String role;
  const AlarmsScreen(this.p, {super.key, required this.role});
  @override State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  final scheduler = AlarmService();
  bool showHistory = false;

  @override
  void initState() {
    super.initState();
    _scheduleVisible();
  }

  Future<void> _scheduleVisible() async {
    await scheduler.init();
    for (final alarm in widget.p.alarms) {
      if ((alarm['enabled'] as num?)?.toInt() != 1 || alarm['completed_at'] != null) continue;
      final target = '${alarm['target_role'] ?? 'admin'}';
      if (widget.role != 'admin' && target != 'all' && target != widget.role) continue;
      await scheduler.schedule(id: '${alarm['id']}', title: '${alarm['title']}', body: '${alarm['notes'] ?? 'Business reminder'}', dueAt: DateTime.parse('${alarm['due_at']}'), repeatRule: '${alarm['repeat_rule'] ?? 'ONCE'}', category: '${alarm['category'] ?? 'CUSTOM'}', enabled: true);
    }
  }

  List<Map<String, Object?>> get visibleAlarms => widget.p.alarms.where((alarm) {
    final target = '${alarm['target_role'] ?? 'admin'}';
    final assigned = widget.role == 'admin' || target == 'all' || target == widget.role;
    final completed = alarm['completed_at'] != null;
    return assigned && (showHistory ? completed : !completed);
  }).toList();

  Future<void> _addAlarm() async {
    final title = TextEditingController();
    final notes = TextEditingController();
    String category = 'CUSTOM', repeat = 'ONCE', priority = 'NORMAL', target = 'all';
    DateTime due = DateTime.now().add(const Duration(hours: 1));
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
      title: const Text('Set business alarm'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Reminder title'), autofocus: true),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'Details / amount / person')),
        DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category'), items: const [DropdownMenuItem(value: 'PAYMENT', child: Text('Payment / collection')), DropdownMenuItem(value: 'FARMER', child: Text('Farmer settlement')), DropdownMenuItem(value: 'CUSTOMER_DUE', child: Text('Customer or party due')), DropdownMenuItem(value: 'LOAN', child: Text('Loan repayment')), DropdownMenuItem(value: 'MILK', child: Text('Milk collection')), DropdownMenuItem(value: 'DELIVERY', child: Text('Delivery')), DropdownMenuItem(value: 'STOCK', child: Text('Stock check')), DropdownMenuItem(value: 'CUSTOM', child: Text('Custom task'))], onChanged: (value) => setDialog(() => category = value ?? category)),
        DropdownButtonFormField<String>(initialValue: repeat, decoration: const InputDecoration(labelText: 'Repeat'), items: const [DropdownMenuItem(value: 'ONCE', child: Text('One time')), DropdownMenuItem(value: 'DAILY', child: Text('Every day')), DropdownMenuItem(value: 'WEEKLY', child: Text('Every week'))], onChanged: (value) => setDialog(() => repeat = value ?? repeat)),
        DropdownButtonFormField<String>(initialValue: priority, decoration: const InputDecoration(labelText: 'Priority'), items: const [DropdownMenuItem(value: 'LOW', child: Text('Low')), DropdownMenuItem(value: 'NORMAL', child: Text('Normal')), DropdownMenuItem(value: 'HIGH', child: Text('High'))], onChanged: (value) => setDialog(() => priority = value ?? priority)),
        if (widget.role == 'admin') DropdownButtonFormField<String>(initialValue: target, decoration: const InputDecoration(labelText: 'Show alarm to'), items: const [DropdownMenuItem(value: 'all', child: Text('Everyone')), DropdownMenuItem(value: 'admin', child: Text('Admin')), DropdownMenuItem(value: 'shop', child: Text('Store')), DropdownMenuItem(value: 'collector', child: Text('Collector')), DropdownMenuItem(value: 'customer', child: Text('Customer'))], onChanged: (value) => setDialog(() => target = value ?? target)),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () async { final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: due); if (date == null || !context.mounted) return; final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(due)); if (time != null) setDialog(() => due = DateTime(date.year, date.month, date.day, time.hour, time.minute)); }, icon: const Icon(Icons.schedule), label: Text('Due: ${due.toLocal()}')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save alarm'))],
    )));
    if (saved != true || !mounted) return;
    try {
      await widget.p.createAlarm(title: title.text, category: category, dueAt: due, notes: notes.text, repeatRule: repeat, priority: priority, targetRole: target);
      final alarm = widget.p.alarms.firstWhere((row) => '${row['title']}' == title.text.trim());
      await scheduler.schedule(id: '${alarm['id']}', title: title.text.trim(), body: notes.text.trim(), dueAt: due, repeatRule: repeat, category: category);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alarm saved and notification scheduled.')));
    } catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save alarm: $error'))); }
  }

  Future<void> _complete(Map<String, Object?> alarm) async { await scheduler.cancel('${alarm['id']}'); await widget.p.completeAlarm('${alarm['id']}'); if (mounted) setState(() {}); }
  Future<void> _snooze(Map<String, Object?> alarm) async { await widget.p.snoozeAlarm('${alarm['id']}', const Duration(minutes: 20)); final until = DateTime.now().add(const Duration(minutes: 20)); await scheduler.schedule(id: '${alarm['id']}', title: '${alarm['title']}', body: '${alarm['notes'] ?? ''}', dueAt: until, category: '${alarm['category'] ?? 'CUSTOM'}'); if (mounted) setState(() {}); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Alarms & reminders'), actions: [IconButton(onPressed: () => setState(() => showHistory = !showHistory), tooltip: showHistory ? 'Show active alarms' : 'Show completed history', icon: Icon(showHistory ? Icons.alarm : Icons.history))]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(color: Theme.of(context).colorScheme.primaryContainer, child: const Padding(padding: EdgeInsets.all(16), child: Text('Set reminders for payments, farmer settlements, customer dues, loans, milk collection, deliveries, stock checks, or any custom task. Android notifications use Kathmandu local time.'))),
      const SizedBox(height: 12),
      if (widget.role == 'admin') FilledButton.icon(onPressed: _addAlarm, icon: const Icon(Icons.add_alarm), label: const Text('Set new alarm')),
      const SizedBox(height: 12),
      if (visibleAlarms.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(showHistory ? 'No completed alarms yet.' : 'No active alarms.'))),
      ...visibleAlarms.map((alarm) => Card(child: ListTile(leading: Icon(alarm['priority'] == 'HIGH' ? Icons.priority_high : Icons.alarm, color: alarm['priority'] == 'HIGH' ? Colors.red : null), title: Text('${alarm['title']}'), subtitle: Text('${alarm['category']} · ${DateTime.parse('${alarm['due_at']}').toLocal()}\n${alarm['notes'] ?? ''}'), isThreeLine: true, trailing: showHistory ? const Icon(Icons.check_circle, color: Colors.green) : PopupMenuButton<String>(onSelected: (value) { if (value == 'done') _complete(alarm); if (value == 'snooze') _snooze(alarm); }, itemBuilder: (_) => const [PopupMenuItem(value: 'snooze', child: Text('Snooze 20 minutes')), PopupMenuItem(value: 'done', child: Text('Mark completed'))]))),
    ],
  );
}
