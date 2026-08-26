import 'dart:async';
import 'package:flutter/material.dart';
import '../../providers/business_provider.dart';
import '../../services/contact_picker_service.dart';
import '../../services/whatsapp_service.dart';
import '../../services/location_service.dart';
import '../../services/role_permissions.dart';

class DairyScreen extends StatefulWidget {
  final BusinessProvider p;
  final String role;
  const DairyScreen(this.p, {super.key, required this.role});
  @override State<DairyScreen> createState() => _DairyScreenState();
}

class _DairyScreenState extends State<DairyScreen> {
  String? farmerId;
  final litres = TextEditingController();
  final fat = TextEditingController(text: '3.5');
  final snf = TextEditingController(text: '6.5');
  final rate = TextEditingController(text: '65');
  String shift = 'MORNING';
  final location = ForegroundLocationService();
  StreamSubscription<ShopDistance>? locationSubscription;
  ShopDistance? distance;
  bool tracking = false;
  bool shopConfigured = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    location.shopLocation().then((value) { if (mounted) setState(() => shopConfigured = value != null); });
    locationSubscription = location.updates.listen((value) { if (mounted) setState(() => distance = value); });
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    location.dispose();
    litres.dispose(); fat.dispose(); snf.dispose(); rate.dispose();
    super.dispose();
  }

  Future<void> configureShop() async {
    final position = await location.currentPosition();
    if (!mounted) return;
    if (position == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable location permission and GPS first'))); return; }
    await location.saveShopLocation(position);
    if (!mounted) return;
    setState(() => shopConfigured = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop location saved on this device')));
  }

  Future<void> toggleTracking() async {
    if (tracking) { await location.stop(); if (mounted) setState(() => tracking = false); return; }
    final started = await location.start();
    if (!mounted) return;
    if (!started) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set shop location and allow foreground GPS permission first'))); return; }
    setState(() { tracking = true; distance = null; });
  }

  Future<void> _addFarmer() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    String? contactError;
    bool pickingContact = false;
    final pageContext = context;
    final ok = await showDialog<bool>(context: pageContext, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
      title: const Text('Add farmer'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Farmer name')),
        Row(children: [
          Expanded(child: TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone / WhatsApp'))),
          IconButton(
            tooltip: 'Import from phone contacts',
            onPressed: pickingContact ? null : () async {
              setDialogState(() { pickingContact = true; contactError = null; });
              try {
                final picked = await ContactPickerService().pickPhone();
                if (dialogContext.mounted) {
                  if (picked == null) {
                    setDialogState(() { pickingContact = false; contactError = 'No phone contact selected or permission denied.'; });
                  } else {
                    setDialogState(() { if (name.text.trim().isEmpty) name.text = picked.name; phone.text = picked.phone; pickingContact = false; });
                  }
                }
              } catch (error) {
                if (dialogContext.mounted) setDialogState(() { pickingContact = false; contactError = 'Could not read contacts: $error'; });
              }
            },
            icon: pickingContact ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.contacts),
          ),
        ]),
        if (contactError != null) Align(alignment: Alignment.centerLeft, child: Text(contactError!, style: const TextStyle(color: Colors.deepOrange, fontSize: 12))),
        TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Save'))],
    )));
    try {
      if (ok == true && name.text.trim().isNotEmpty) {
        await widget.p.addFarmer(name.text.trim(), phone.text.trim(), address.text.trim(), 65);
        if (mounted) setState(() {});
      }
    } catch (error) {
      if (pageContext.mounted) ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(content: Text('Could not save farmer: $error')));
    } finally {
      name.dispose(); phone.dispose(); address.dispose();
    }
  }

  Future<void> _shareFarmerSettlement(Map<String, Object?> farmer) async {
    final id = '${farmer['id']}';
    final rows = widget.p.milk.where((entry) => '${entry['farmer_id']}' == id).toList();
    final litresTotal = rows.fold<double>(0, (sum, entry) => sum + ((entry['litres'] as num?)?.toDouble() ?? 0));
    final amountTotal = rows.fold<double>(0, (sum, entry) => sum + ((entry['amount'] as num?)?.toDouble() ?? 0));
    final balance = await widget.p.farmerBalance(id);
    final phone = '${farmer['phone'] ?? ''}'.trim();
    if (phone.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a farmer phone number before sharing WhatsApp settlement')));
      return;
    }
    final message = '*GAJURMUKHI DAIRY & STORE*\nFarmer collection settlement\nDate: ${DateTime.now().toLocal()}\nFarmer: ${farmer['name']}\nMilk collected: ${litresTotal.toStringAsFixed(2)} L\nCollection value: NPR ${amountTotal.toStringAsFixed(2)}\nBalance payable: NPR ${balance.toStringAsFixed(2)}\nValue for Life';
    try {
      await WhatsAppService().openMessage(phone, message);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open WhatsApp: $error')));
    }
  }

  Future<void> _editFarmerRate(Map<String, Object?> farmer) async {
    final value = TextEditingController(text: '${farmer['rate_per_litre'] ?? rate.text}');
    final result = await showDialog<double>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('Fixed farmer rate · ${farmer['name']}'),
      content: TextField(controller: value, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'NPR per litre')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, double.tryParse(value.text.trim())), child: const Text('Save rate'))],
    ));
    value.dispose();
    if (result == null) return;
    try {
      await widget.p.updateFarmerRate('${farmer['id']}', result);
      if ('${farmer['id']}' == farmerId && mounted) rate.text = result.toStringAsFixed(2);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Farmer rate saved')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save farmer rate: $error')));
    }
  }

  Future<void> _settleFarmer(Map<String, Object?> farmer) async {
    final balance = await widget.p.farmerBalance('${farmer['id']}');
    if (!mounted) return;
    if (balance <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This farmer has no unpaid collection balance'))); return; }
    final amount = TextEditingController(text: balance.toStringAsFixed(2));
    final note = TextEditingController(text: 'Milk collection settlement');
    String method = 'CASH';
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
      title: Text('Pay farmer · ${farmer['name']}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Payable balance: NPR ${balance.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Payment amount (NPR)')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(initialValue: method, decoration: const InputDecoration(labelText: 'Payment method'), items: const [DropdownMenuItem(value: 'CASH', child: Text('Cash')), DropdownMenuItem(value: 'QR', child: Text('QR')), DropdownMenuItem(value: 'BANK', child: Text('Bank'))], onChanged: (value) => setDialogState(() => method = value ?? method)),
        const SizedBox(height: 8),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Record payment'))],
    )));
    if (ok == true) {
      try {
        await widget.p.recordFarmerPayment(farmerId: '${farmer['id']}', amount: double.tryParse(amount.text.trim()) ?? 0, method: method, note: note.text.trim());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Farmer payment recorded')));
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not record farmer payment: $error')));
      }
    }
    amount.dispose(); note.dispose();
  }

  Future<void> saveCollection() async {
    if (!RolePermissions.canCreateMilkCollection(widget.role)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your role cannot add milk collections')));
      return;
    }
    if (farmerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a farmer before saving')));
      return;
    }
    final litresValue = double.tryParse(litres.text.trim());
    final fatValue = double.tryParse(fat.text.trim());
    final snfValue = double.tryParse(snf.text.trim());
    final rateValue = double.tryParse(rate.text.trim());
    if (litresValue == null || litresValue <= 0 || fatValue == null || fatValue <= 0 || snfValue == null || snfValue <= 0 || rateValue == null || rateValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter litres, FAT, SNF, and rate values greater than zero')));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.p.addMilkCollection(farmerId: farmerId!, litres: litresValue, fat: fatValue, snf: snfValue, rate: rateValue, shift: shift);
      if (!mounted) return;
      litres.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Milk collection recorded')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save collection: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> removeCollection(String id) async {
    if (!RolePermissions.canRemoveMilkCollection(widget.role)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Admin can remove collection records')));
      return;
    }
    try {
      await widget.p.removeMilkCollection(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collection removed')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not remove collection: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('Milk Collection', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.location_on, color: Colors.blue), const SizedBox(width: 8), const Expanded(child: Text('Collector check-in', style: TextStyle(fontWeight: FontWeight.bold))), Text(tracking ? 'TRACKING' : 'OFF', style: TextStyle(color: tracking ? Colors.green : Colors.grey, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 6),
        Text(distance == null ? (shopConfigured ? 'Shop configured. Start collection to see distance.' : 'Configure the shop location before starting.') : 'Distance from shop: ${distance!.label}'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton.icon(onPressed: configureShop, icon: const Icon(Icons.my_location), label: Text(shopConfigured ? 'Reset shop point' : 'Set shop location')), FilledButton.icon(onPressed: toggleTracking, icon: Icon(tracking ? Icons.stop : Icons.play_arrow), label: Text(tracking ? 'Stop check-in' : 'Start check-in'))]),
        const SizedBox(height: 4),
        const Text('Location is used only while this foreground check-in is active.', style: TextStyle(fontSize: 11, color: Colors.black54)),
      ]))),
      Row(children: [
        const Expanded(child: Text('Farmer / supplier', style: TextStyle(fontWeight: FontWeight.bold))),
        TextButton.icon(onPressed: _addFarmer, icon: const Icon(Icons.person_add_alt_1), label: const Text('Add farmer')),
      ]),
      DropdownButtonFormField<String>(
        initialValue: farmerId,
        items: widget.p.farmers.map((f) => DropdownMenuItem(
          value: '${f['id']}', child: Text('${f['name']}'),
        )).toList(),
        onChanged: (v) {
          final selected = widget.p.farmers.where((farmer) => '${farmer['id']}' == v).toList();
          setState(() { farmerId = v; if (selected.isNotEmpty) rate.text = '${selected.first['rate_per_litre'] ?? rate.text}'; });
        },
        decoration: const InputDecoration(labelText: 'Farmer'),
      ),
      if (widget.p.farmers.isEmpty) const Padding(padding: EdgeInsets.only(top: 6), child: Text('No farmers registered yet. Add a farmer from Parties before saving collection.', style: TextStyle(color: Colors.deepOrange, fontSize: 12))),
      const SizedBox(height: 10),
      TextField(controller: litres, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Milk Litres')),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(controller: fat, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'FAT %'))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: snf, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'SNF %'))),
      ]),
      const SizedBox(height: 10),
      TextField(controller: rate, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Rate / Litre')),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'MORNING', label: Text('Morning')),
          ButtonSegment(value: 'EVENING', label: Text('Evening')),
        ],
        selected: {shift},
        onSelectionChanged: (v) => setState(() => shift = v.first),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: RolePermissions.canCreateMilkCollection(widget.role) && !saving ? saveCollection : null,
        icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
        label: Text(saving ? 'Saving…' : 'Save Collection'),
      ),
      const Divider(height: 30),
      const Text('Today’s Collection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ...widget.p.farmers.map((farmer) => ListTile(
        leading: const Icon(Icons.agriculture_outlined),
        title: Text('${farmer['name']}'),
        subtitle: Text('${farmer['phone'] ?? 'No phone'} · Fixed rate NPR ${farmer['rate_per_litre'] ?? 0}/L'),
        trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'pay') _settleFarmer(farmer); if (value == 'rate') _editFarmerRate(farmer); if (value == 'share') _shareFarmerSettlement(farmer); }, itemBuilder: (_) => const [PopupMenuItem(value: 'pay', child: Text('Pay farmer bill')), PopupMenuItem(value: 'rate', child: Text('Set fixed rate')), PopupMenuItem(value: 'share', child: Text('Share settlement on WhatsApp'))]),
      )),
      const Divider(),
      ...widget.p.milk.map((m) => ListTile(
        title: Text('${m['litres']} L • FAT ${m['fat']} • SNF ${m['snf']}'),
        subtitle: Text('${m['shift']} • Rate NPR ${m['rate']}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('NPR ${m['amount']}'), if (RolePermissions.canRemoveMilkCollection(widget.role)) IconButton(tooltip: 'Remove collection', icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => removeCollection('${m['id']}'))]),
      )),
    ],
  );
}
