import 'dart:async';
import 'package:flutter/material.dart';
import '../../providers/business_provider.dart';
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
      DropdownButtonFormField<String>(
        initialValue: farmerId,
        items: widget.p.farmers.map((f) => DropdownMenuItem(
          value: '${f['id']}', child: Text('${f['name']}'),
        )).toList(),
        onChanged: (v) => setState(() => farmerId = v),
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
      ...widget.p.milk.map((m) => ListTile(
        title: Text('${m['litres']} L • FAT ${m['fat']} • SNF ${m['snf']}'),
        subtitle: Text('${m['shift']} • Rate NPR ${m['rate']}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('NPR ${m['amount']}'), if (RolePermissions.canRemoveMilkCollection(widget.role)) IconButton(tooltip: 'Remove collection', icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => removeCollection('${m['id']}'))]),
      )),
    ],
  );
}
