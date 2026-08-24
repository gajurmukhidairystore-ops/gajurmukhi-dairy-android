import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/business_provider.dart';
import '../../services/contact_picker_service.dart';
import '../../services/location_service.dart';
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
      try {
        if (advance) {
          await widget.p.recordAdvance(id, value, method, note.text.trim().isEmpty ? 'Advance' : note.text.trim());
        } else {
          await widget.p.recordPayment(id, value, method, note.text.trim().isEmpty ? 'Customer payment' : note.text.trim());
        }
        if (!mounted) return;
        ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Ledger updated')));
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Could not update ledger: $error')));
      }
    }
  }

  Future<void> _remind(BuildContext context, Map<String, Object?> customer) async {
    final amount = (customer['balance'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This customer has no outstanding balance'))); return; }
    final name = '${customer['name'] ?? 'Customer'}';
    final message = 'Hello $name, this is a friendly reminder that your outstanding balance is NPR ${amount.toStringAsFixed(2)}. Thank you — Gajurmukhi Dairy & Store.';
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

  Future<void> _openMap(Map<String, Object?> customer) async {
    final lat = (customer['latitude'] as num?)?.toDouble();
    final lng = (customer['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No GPS location saved for this customer')));
      return;
    }
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the map application')));
    }
  }

  Future<void> _captureCustomerLocation(Map<String, Object?> customer) async {
    final position = await ForegroundLocationService().currentPosition();
    if (position == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable GPS and grant location permission to capture this address')));
      return;
    }
    try {
      await widget.p.updateCustomerLocation('${customer['id']}', latitude: position.latitude, longitude: position.longitude, accuracy: position.accuracy);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GPS location saved (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save customer location: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
    Row(children: [const Expanded(child: Text('Customer ledger', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: () => _addCustomer(context), icon: const Icon(Icons.person_add), label: const Text('Add customer'))]),
    const SizedBox(height: 12),
    ...widget.p.customers.map((c) {
      final hasLocation = c['latitude'] != null && c['longitude'] != null;
      final address = '${c['address'] ?? ''}'.trim();
      final locationLabel = hasLocation ? 'GPS location saved' : 'GPS location not captured';
      return Card(child: ListTile(
        leading: CircleAvatar(child: Icon(hasLocation ? Icons.location_on : Icons.person)),
        title: Text('${c['name']}'),
        subtitle: Text('${c['phone'] ?? ''}\n${address.isEmpty ? 'Address not entered' : address}\nOutstanding: NPR ${c['balance'] ?? 0} · $locationLabel'),
        isThreeLine: true,
        onTap: () => _statement(context, c),
        trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'payment') _record(context, c, advance: false); if (v == 'advance') _record(context, c, advance: true); if (v == 'statement') _statement(context, c); if (v == 'remind') _remind(context, c); if (v == 'capture') _captureCustomerLocation(c); if (v == 'map') _openMap(c); }, itemBuilder: (_) => const [PopupMenuItem(value: 'payment', child: Text('Record payment')), PopupMenuItem(value: 'advance', child: Text('Record advance')), PopupMenuItem(value: 'statement', child: Text('View statement')), PopupMenuItem(value: 'remind', child: Text('Send credit reminder')), PopupMenuItem(value: 'capture', child: Text('Capture/update GPS location')), PopupMenuItem(value: 'map', child: Text('Open customer on map'))]),
      ));
    })
  ]);

  Future<void> _addCustomer(BuildContext context) async {
    final pageContext = context;
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    Position? capturedPosition;
    String? locationError;
    String? contactError;
    bool locating = false;
    bool pickingContact = false;
    final ok = await showDialog<bool>(context: pageContext, builder: (_) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(
      title: const Text('Add customer'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        Row(children: [
          Expanded(child: TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'))),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Import from phone contacts',
            onPressed: pickingContact ? null : () async {
              setDialogState(() { pickingContact = true; contactError = null; });
              try {
                final picked = await ContactPickerService().pickPhone();
                if (picked == null) {
                  if (dialogContext.mounted) setDialogState(() { pickingContact = false; contactError = 'No phone contact was selected or permission was denied.'; });
                  return;
                }
                if (dialogContext.mounted) {
                  setDialogState(() {
                    if (name.text.trim().isEmpty) name.text = picked.name;
                    phone.text = picked.phone;
                    pickingContact = false;
                  });
                }
              } catch (error) {
                if (dialogContext.mounted) setDialogState(() { pickingContact = false; contactError = 'Could not read phone contacts: $error'; });
              }
            },
            icon: pickingContact ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.contacts),
          ),
        ]),
        if (contactError != null) Align(alignment: Alignment.centerLeft, child: Text(contactError!, style: const TextStyle(color: Colors.deepOrange, fontSize: 12))),
        TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'House address / delivery instructions')),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(
          onPressed: locating ? null : () async {
            setDialogState(() { locating = true; locationError = null; });
            final position = await ForegroundLocationService().currentPosition();
            if (position == null) {
              setDialogState(() { locating = false; locationError = 'Enable GPS and grant location permission, then try again.'; });
            } else {
              capturedPosition = position;
              setDialogState(() => locating = false);
            }
          },
          icon: locating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
          label: Text(locating ? 'Reading GPS…' : 'Capture current house GPS location'),
        )),
        if (capturedPosition != null) Align(alignment: Alignment.centerLeft, child: Text('Captured: ${capturedPosition!.latitude.toStringAsFixed(5)}, ${capturedPosition!.longitude.toStringAsFixed(5)}', style: TextStyle(color: Theme.of(dialogContext).colorScheme.primary))),
        if (locationError != null) Align(alignment: Alignment.centerLeft, child: Text(locationError!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error))),
        const SizedBox(height: 4),
        const Align(alignment: Alignment.centerLeft, child: Text('GPS capture is optional, but required for delivery tracking and arrival calling.', style: TextStyle(fontSize: 12))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))],
    )));
    if (ok == true && name.text.trim().isNotEmpty) {
      try {
        await widget.p.addCustomer(name.text.trim(), phone.text.trim(), address.text.trim(), latitude: capturedPosition?.latitude, longitude: capturedPosition?.longitude, locationAccuracy: capturedPosition?.accuracy);
      } catch (error) {
        if (!pageContext.mounted) return;
        ScaffoldMessenger.of(pageContext).showSnackBar(SnackBar(content: Text('Could not save customer: $error')));
      }
    }
  }
}
