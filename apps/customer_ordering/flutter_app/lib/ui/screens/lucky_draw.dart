import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/business_provider.dart';
import '../../services/lucky_draw_service.dart';

class LuckyDrawScreen extends StatefulWidget {
  final String role;
  const LuckyDrawScreen({super.key, required this.role});

  @override
  State<LuckyDrawScreen> createState() => _LuckyDrawScreenState();
}

class _LuckyDrawScreenState extends State<LuckyDrawScreen> {
  final monthKey = TextEditingController(text: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}');
  final monthLabel = TextEditingController(text: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')} Monthly Draw');
  final announcement = TextEditingController(text: 'Thank you for shopping with Gajurmukhi Dairy & Store.');
  final customerName = TextEditingController();
  final purchaseTotal = TextEditingController();
  final identityType = TextEditingController(text: 'Identity document');
  final tokenNumber = TextEditingController();
  final prizeTitles = List.generate(3, (index) => TextEditingController(text: '${index == 0 ? '1st' : index == 1 ? '2nd' : '3rd'} Prize'));
  final prizeDescriptions = List.generate(3, (_) => TextEditingController());
  String? selectedCustomerId;
  String? identityReference;
  bool consented = false;
  bool busy = false;

  @override
  void dispose() {
    monthKey.dispose(); monthLabel.dispose(); announcement.dispose(); customerName.dispose(); purchaseTotal.dispose(); identityType.dispose(); tokenNumber.dispose();
    for (final controller in [...prizeTitles, ...prizeDescriptions]) controller.dispose();
    super.dispose();
  }

  Future<void> pickIdentity() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result != null && result.files.single.path != null) setState(() => identityReference = result.files.single.path);
  }

  Future<void> createDraw(BusinessProvider p) async {
    setState(() => busy = true);
    try {
      await p.createLuckyDraw(
        monthKey: monthKey.text,
        monthLabel: monthLabel.text,
        announcement: announcement.text,
        drawDate: DateTime.now().add(const Duration(days: 30)),
        prizes: List.generate(3, (index) => {'title': prizeTitles[index].text, 'description': prizeDescriptions[index].text}),
        createdBy: widget.role,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monthly lucky draw created')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', '')))); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> registerToken(BusinessProvider p, Map<String, Object?> draw) async {
    setState(() => busy = true);
    try {
      final token = await p.issueLuckyToken(
        drawId: '${draw['id']}', purchaseTotal: double.tryParse(purchaseTotal.text) ?? 0,
        customerName: customerName.text, customerId: selectedCustomerId,
        identityReference: identityReference ?? '', identityType: identityType.text,
        consented: consented, issuedBy: widget.role, tokenNumber: tokenNumber.text,
      );
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Token $token registered'))); setState(() { customerName.clear(); purchaseTotal.clear(); tokenNumber.clear(); identityReference = null; consented = false; }); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Invalid argument(s): ', '')))); }
    if (mounted) setState(() => busy = false);
  }

  Future<void> runDraw(BusinessProvider p, Map<String, Object?> draw) async {
    setState(() => busy = true);
    try {
      final message = await p.runLuckyDraw(drawId: '${draw['id']}');
      if (mounted) await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Winners published'), content: SingleChildScrollView(child: SelectableText(message)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', '')))); }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BusinessProvider>();
    final draw = p.luckyDraws.isEmpty ? null : p.luckyDraws.first;
    final winners = draw == null ? const <Map<String, Object?>>[] : p.luckyDrawWinners.where((winner) => '${winner['draw_id']}' == '${draw['id']}').toList();
    final tokens = draw == null ? const <Map<String, Object?>>[] : p.luckyDrawTokens.where((token) => '${token['draw_id']}' == '${draw['id']}').toList();
    return RefreshIndicator(
      onRefresh: p.refresh,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Lucky Draw', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('Free monthly promotion for customers purchasing NPR 1,000 or more. Public results show token number and masked name only.'),
        const SizedBox(height: 16),
        if (widget.role == 'admin') ...[
          _sectionTitle('Admin: configure monthly draw'),
          if (draw == null) ...[
            TextField(controller: monthKey, decoration: const InputDecoration(labelText: 'Month key')),
            const SizedBox(height: 10), TextField(controller: monthLabel, decoration: const InputDecoration(labelText: 'Public month label')),
            const SizedBox(height: 10), TextField(controller: announcement, maxLines: 3, decoration: const InputDecoration(labelText: 'Announcement message')),
            const SizedBox(height: 10),
            ...List.generate(3, (index) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Expanded(child: TextField(controller: prizeTitles[index], decoration: InputDecoration(labelText: '${index + 1}. Prize title'))), const SizedBox(width: 8), Expanded(child: TextField(controller: prizeDescriptions[index], decoration: const InputDecoration(labelText: 'Prize detail')))]))),
            FilledButton.icon(onPressed: busy ? null : () => createDraw(p), icon: const Icon(Icons.add), label: const Text('Create monthly draw')),
          ] else ...[
            Card(child: ListTile(title: Text('${draw['month_label']} · ${draw['status']}'), subtitle: Text('${tokens.length} eligible token(s) · draw date ${draw['draw_date']}'))),
            if ('${draw['status']}' == 'OPEN') FilledButton.icon(onPressed: busy || tokens.length < 3 ? null : () => runDraw(p, draw), icon: const Icon(Icons.casino), label: Text(tokens.length < 3 ? 'Need at least 3 eligible tokens' : 'Select and publish winners')),
          ],
          const SizedBox(height: 16),
        ],
        if ((widget.role == 'admin' || widget.role == 'shop') && draw != null && '${draw['status']}' == 'OPEN') ...[
          _sectionTitle('Store: issue eligible customer token'),
          DropdownButtonFormField<String>(value: selectedCustomerId, decoration: const InputDecoration(labelText: 'Existing customer (optional)'), items: [const DropdownMenuItem(value: null, child: Text('Enter customer name below')), ...p.customers.map((customer) => DropdownMenuItem(value: '${customer['id']}', child: Text('${customer['name']}')))], onChanged: (value) => setState(() { selectedCustomerId = value; if (value != null) { final customer = p.customers.firstWhere((row) => '${row['id']}' == value); customerName.text = '${customer['name']}'; } })),
          const SizedBox(height: 10), TextField(controller: customerName, decoration: const InputDecoration(labelText: 'Customer full name')),
          const SizedBox(height: 10), TextField(controller: purchaseTotal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Eligible bill total (NPR)')),
          const SizedBox(height: 10), TextField(controller: tokenNumber, decoration: const InputDecoration(labelText: 'Token number (leave blank to generate)')),
          const SizedBox(height: 10), TextField(controller: identityType, decoration: const InputDecoration(labelText: 'Identity type')),
          const SizedBox(height: 8), OutlinedButton.icon(onPressed: pickIdentity, icon: const Icon(Icons.upload_file), label: Text(identityReference == null ? 'Attach identity photo/document' : 'Identity document attached')),
          CheckboxListTile(value: consented, onChanged: (value) => setState(() => consented = value ?? false), title: const Text('Customer consented to private identity-document storage'), contentPadding: EdgeInsets.zero),
          FilledButton.icon(onPressed: busy ? null : () => registerToken(p, draw), icon: const Icon(Icons.confirmation_number), label: const Text('Register token')),
          const SizedBox(height: 16),
        ],
        _sectionTitle('Customer: published results'),
        if (winners.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Winners will appear here after the Admin completes the monthly draw.'))),
        ...winners.map((winner) => Card(child: ListTile(leading: CircleAvatar(child: Text('${winner['prize_id']}'.isEmpty ? '?' : '${winner['prize_id']}')), title: Text('${winner['token_number']}'), subtitle: Text('${winner['masked_name']} · Public masked name only')))),
      ]),
    );
  }

  Widget _sectionTitle(String text) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)));
}
