import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/business_provider.dart';
import '../../services/ai_command_service.dart';
import '../../services/printing_service.dart';
import '../../services/whatsapp_service.dart';
import 'barcode_scanner.dart';

class BillingScreen extends StatefulWidget {
  final BusinessProvider p;
  final String? initialBarcode;
  final VoidCallback? onInitialBarcodeConsumed;
  const BillingScreen(this.p, {super.key, this.initialBarcode, this.onInitialBarcodeConsumed});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final search = TextEditingController();
  final customerPhone = TextEditingController();
  final upiId = TextEditingController();
  final discountReason = TextEditingController();
  final whatsappTemplate = TextEditingController(text: WhatsAppService.defaultTemplate);
  final List<Map<String, dynamic>> cart = [];
  String payment = 'CASH';
  double discount = 0;
  double paid = 0;
  double taxRate = 0;
  String selectedTaxGroupId = 'NONE';
  List<Map<String, dynamic>> paymentTenders = [];
  String? selectedCustomerId;
  String? lastLuckyToken;
  List<Map<String, dynamic>> lastSavedCart = [];
  double lastSavedSubtotal = 0;
  double lastSavedTotal = 0;
  double lastSavedPaid = 0;
  double lastSavedDue = 0;
  double lastSavedDiscount = 0;
  String lastSavedDiscountReason = '';
  String lastSavedPayment = 'CASH';
  String lastSavedQrStatus = 'not_applicable';
  String lastSavedCustomerName = 'Walk-in Customer';
  String lastSavedCustomerPhone = '';

  @override
  void initState() {
    super.initState();
    _loadWhatsAppTemplate();
    final barcode = widget.initialBarcode?.trim();
    if (barcode != null && barcode.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await addProductByBarcode(barcode);
        widget.onInitialBarcodeConsumed?.call();
      });
    }
  }

  Future<void> _loadWhatsAppTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('whatsapp_template');
    if (!mounted || saved == null) return;
    whatsappTemplate.text = WhatsAppService.normalizeTemplate(saved);
    setState(() {});
  }

  Future<void> _saveWhatsAppTemplate() async {
    final unsupported = WhatsAppService.unsupportedVariables(whatsappTemplate.text);
    if (unsupported.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unsupported variables: ${unsupported.join(', ')}')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('whatsapp_template', whatsappTemplate.text.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp template saved')));
  }

  double get subtotal => cart.fold(0, (s, i) => s + (i['total'] as num).toDouble());
  double get tax => BusinessProvider.calculateTax(subtotal: subtotal, discount: discount, ratePercent: taxRate);
  double get total => ((subtotal - discount).clamp(0, double.infinity) + tax).toDouble();
  double get due => (total - paid).clamp(0, double.infinity).toDouble();
  bool get hasQrTender => payment == 'QR' || (payment == 'SPLIT' && paymentTenders.any((t) => '${t['method']}' == 'QR'));

  String get qrStatus => hasQrTender ? (paid >= total && total > 0 ? 'received' : 'pending') : 'not_applicable';

  String get paymentQrData => 'upi://pay?pa=${Uri.encodeComponent(upiId.text.trim())}&pn=${Uri.encodeComponent('Gajurmukhi Dairy & Store')}&am=${total.toStringAsFixed(2)}&cu=${AppSettingsService.currencyCode.value}&tn=${Uri.encodeComponent('Gajurmukhi bill')}';

  Map<String, Object?>? customerById(String? id) {
    for (final customer in widget.p.customers) {
      if ('${customer['id']}' == id) return customer;
    }
    return null;
  }

  @override
  void dispose() {
    search.dispose();
    customerPhone.dispose();
    upiId.dispose();
    discountReason.dispose();
    whatsappTemplate.dispose();
    super.dispose();
  }

  void addProduct(Map<String, Object?> product) {
    final partyRate = (customerById(selectedCustomerId)?['milk_rate'] as num?)?.toDouble() ?? 0;
    final isMilk = '${product['name']}'.trim().toLowerCase() == 'milk 1 ltr';
    final price = isMilk && partyRate > 0 ? partyRate : (product['sale_price'] as num).toDouble();
    final existing = cart.where((e) => e['productId'] == product['id']).toList();
    if (existing.isNotEmpty) {
      existing.first['qty'] += 1;
      existing.first['total'] = existing.first['qty'] * price;
    } else {
      cart.add({
        'productId': product['id'],
        'name': product['name'],
        'qty': 1.0,
        'price': price,
        'discount': 0.0,
        'total': price,
      });
    }
    setState(() {});
  }

  void selectCustomer(String? customerId) {
    setState(() {
      selectedCustomerId = customerId;
      customerPhone.text = '${customerById(customerId)?['phone'] ?? ''}';
      final fixedRate = (customerById(customerId)?['milk_rate'] as num?)?.toDouble() ?? 0;
      for (final item in cart) {
        if ('${item['name']}'.trim().toLowerCase() != 'milk 1 ltr') continue;
        final products = widget.p.products.where((row) => '${row['id']}' == '${item['productId']}').toList();
        final standardRate = products.isEmpty ? (item['price'] as num).toDouble() : (products.first['sale_price'] as num).toDouble();
        item['price'] = fixedRate > 0 ? fixedRate : standardRate;
        item['total'] = (item['qty'] as num).toDouble() * (item['price'] as num).toDouble();
      }
    });
  }

  Future<void> addProductByBarcode(String barcode) async {
    final normalized = barcode.trim();
    if (!mounted || normalized.isEmpty) return;
    final product = widget.p.products.where((row) => '${row['barcode'] ?? ''}'.trim() == normalized && (row['active'] ?? 1) != 0).toList();
    if (product.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No active inventory item has barcode $normalized. Add or edit the item in Inventory first.')));
      return;
    }
    addProduct(product.first);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${product.first['name']} added to the bill')));
  }

  Future<void> scanAndAddProduct() async {
    final barcode = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
    if (!mounted || barcode == null || barcode.isEmpty) return;
    await addProductByBarcode(barcode);
  }

  Future<Map<String, Object?>?> _collectLuckyDrawDetails() async {
    final name = TextEditingController(text: '${customerById(selectedCustomerId)?['name'] ?? ''}');
    final identityType = TextEditingController(text: 'Identity document');
    final token = TextEditingController();
    String? identityReference;
    bool consented = false;
    final result = await showDialog<Map<String, Object?>>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Eligible lucky-draw purchase'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('This bill qualifies for one free token. Store identity information only with customer consent.'),
        const SizedBox(height: 12), TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer full name')),
        const SizedBox(height: 10), TextField(controller: token, decoration: const InputDecoration(labelText: 'Token number (optional)')),
        const SizedBox(height: 10), TextField(controller: identityType, decoration: const InputDecoration(labelText: 'Identity type')),
        const SizedBox(height: 8), OutlinedButton.icon(onPressed: () async { final picked = await FilePicker.platform.pickFiles(withData: false); if (picked?.files.single.path != null) setDialogState(() => identityReference = picked!.files.single.path); }, icon: const Icon(Icons.upload_file), label: Text(identityReference == null ? 'Attach identity photo/document' : 'Document attached')),
        CheckboxListTile(value: consented, onChanged: (value) => setDialogState(() => consented = value ?? false), title: const Text('Customer consented'), contentPadding: EdgeInsets.zero),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Skip token')), FilledButton(onPressed: () => Navigator.pop(dialogContext, {'name': name.text, 'token': token.text, 'identityType': identityType.text, 'identityReference': identityReference, 'consented': consented}), child: const Text('Register token'))],
    )));
    name.dispose(); identityType.dispose(); token.dispose();
    return result;
  }

  Future<void> save() async {
    if (cart.isEmpty) return;
    final savedCart = cart.map((item) => Map<String, dynamic>.from(item)).toList();
    final savedSubtotal = subtotal;
    final savedTotal = total;
    final savedDue = due;
    lastSavedCart = savedCart;
    lastSavedSubtotal = savedSubtotal;
    lastSavedTotal = savedTotal;
    lastSavedPaid = paid;
    lastSavedDue = savedDue;
    lastSavedDiscount = discount;
    lastSavedDiscountReason = discountReason.text.trim();
    lastSavedPayment = payment;
    lastSavedQrStatus = qrStatus;
    lastSavedCustomerName = '${customerById(selectedCustomerId)?['name'] ?? 'Walk-in Customer'}';
    lastSavedCustomerPhone = customerPhone.text.trim();
    lastLuckyToken = null;
    await widget.p.createInvoice(customerId: selectedCustomerId, items: cart, discount: discount, discountReason: discountReason.text.trim(), paid: paid, paymentMethod: payment, qrStatus: qrStatus, taxRate: taxRate, paymentSplits: payment == 'SPLIT' ? paymentTenders : const []);
    final openDraws = widget.p.luckyDraws.where((row) => '${row['status']}' == 'OPEN').toList();
    final draw = openDraws.isEmpty ? null : openDraws.first;
    if (savedTotal >= 1000 && draw != null && mounted) {
      final details = await _collectLuckyDrawDetails();
      if (details != null) {
        try {
          lastLuckyToken = await widget.p.issueLuckyToken(drawId: '${draw['id']}', purchaseTotal: savedTotal, customerName: '${details['name']}', customerId: selectedCustomerId, identityReference: '${details['identityReference'] ?? ''}', identityType: '${details['identityType']}', consented: details['consented'] == true, issuedBy: 'shop', tokenNumber: '${details['token']}');
        } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Invalid argument(s): ', '')))); }
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lastLuckyToken == null ? 'Invoice saved' : 'Invoice saved with lucky token $lastLuckyToken')));
    setState(() { cart.clear(); paid = 0; discount = 0; discountReason.clear(); paymentTenders = []; });
  }

  Future<void> _manageSplitTenders() async {
    final cash = TextEditingController(text: '${paymentTenders.where((t) => '${t['method']}' == 'CASH').fold<double>(0, (s, t) => s + ((t['amount'] as num?)?.toDouble() ?? 0))}');
    final qr = TextEditingController(text: '${paymentTenders.where((t) => '${t['method']}' == 'QR').fold<double>(0, (s, t) => s + ((t['amount'] as num?)?.toDouble() ?? 0))}');
    final bank = TextEditingController(text: '${paymentTenders.where((t) => '${t['method']}' == 'BANK').fold<double>(0, (s, t) => s + ((t['amount'] as num?)?.toDouble() ?? 0))}');
    final result = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Split payment tenders'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Invoice total: NPR ${total.toStringAsFixed(2)}'),
        const SizedBox(height: 10),
        TextField(controller: cash, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cash amount')),
        const SizedBox(height: 8),
        TextField(controller: qr, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'QR amount')),
        const SizedBox(height: 8),
        TextField(controller: bank, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Bank amount')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () {
        final values = <Map<String, dynamic>>[];
        for (final entry in [('CASH', cash.text), ('QR', qr.text), ('BANK', bank.text)]) {
          final amount = double.tryParse(entry.$2.trim()) ?? 0;
          if (amount > 0) values.add({'method': entry.$1, 'amount': amount, 'reference': null});
        }
        final sum = values.fold<double>(0, (s, item) => s + (item['amount'] as double));
        if ((sum - total).abs() > 0.01) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Tender amounts must equal the invoice total')));
          return;
        }
        Navigator.pop(dialogContext, values);
      }, child: const Text('Apply'))],
    ));
    cash.dispose(); qr.dispose(); bank.dispose();
    if (result == null) return;
    setState(() { paymentTenders = result; paid = result.fold<double>(0, (s, item) => s + (item['amount'] as num).toDouble()); });
  }

  Future<void> _exportBackup() async {
    try {
      final source = await widget.p.exportBackup();
      final file = XFile.fromData(Uint8List.fromList(utf8.encode(source)), name: 'gajurmukhi-backup-${DateTime.now().millisecondsSinceEpoch}.json', mimeType: 'application/json');
      await Share.shareXFiles([file], text: 'Gajurmukhi Dairy & Store offline backup');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export backup: $error')));
    }
  }

  Future<void> _restoreBackup() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (!mounted || picked == null) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The selected backup file could not be read')));
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Restore backup?'),
      content: const Text('Restore replaces the local database with this backup. Export the current data first if you may need it later.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Restore'))],
    ));
    if (confirmed != true) return;
    try {
      await widget.p.restoreBackup(utf8.decode(bytes));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored successfully')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not restore backup: $error')));
    }
  }

  Future<void> _addTaxGroup() async {
    final name = TextEditingController();
    final rate = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Add tax group'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Tax group name')),
        const SizedBox(height: 8),
        TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Rate (%)')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save'))],
    ));
    if (ok == true) {
      try {
        await widget.p.addTaxGroup(name: name.text, rate: double.tryParse(rate.text) ?? -1);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tax group saved')));
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save tax group: $error')));
      }
    }
    name.dispose(); rate.dispose();
  }

  Future<void> _archiveTaxGroup(String id) async {
    try {
      await widget.p.archiveTaxGroup(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tax group archived')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not archive tax group: $error')));
    }
  }

  Future<void> shareWhatsApp() async {
    final sourceCart = cart.isEmpty ? lastSavedCart : cart;
    if (sourceCart.isEmpty) return;
    final usingSavedBill = cart.isEmpty;
    final message = WhatsAppService.dailyTransactionMessage(
      invoiceNumber: usingSavedBill ? 'SAVED-${DateTime.now().millisecondsSinceEpoch}' : 'DRAFT-${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      customerName: usingSavedBill ? lastSavedCustomerName : '${customerById(selectedCustomerId)?['name'] ?? 'Walk-in Customer'}',
      customerPhone: (usingSavedBill ? lastSavedCustomerPhone : customerPhone.text.trim()).isEmpty ? null : (usingSavedBill ? lastSavedCustomerPhone : customerPhone.text.trim()),
      items: sourceCart.map((item) => <String, Object?>{'name': item['name'], 'quantity': item['qty'], 'unitPrice': item['price']}).toList(),
      subtotal: usingSavedBill ? lastSavedSubtotal : subtotal,
      discount: usingSavedBill ? lastSavedDiscount : discount,
      discountReason: usingSavedBill ? lastSavedDiscountReason : discountReason.text.trim(),
      total: usingSavedBill ? lastSavedTotal : total,
      paid: usingSavedBill ? lastSavedPaid : paid,
      due: usingSavedBill ? lastSavedDue : due,
      paymentMethod: usingSavedBill ? lastSavedPayment : payment,
      upiId: upiId.text.trim().isEmpty ? null : upiId.text.trim(),
      qrStatus: usingSavedBill ? lastSavedQrStatus : qrStatus,
      luckyToken: lastLuckyToken,
      template: whatsappTemplate.text,
    );
    await WhatsAppService().openMessage(usingSavedBill ? lastSavedCustomerPhone : customerPhone.text.trim(), message);
  }

  @override
  Widget build(BuildContext context) {
    final needle = search.text.trim().toLowerCase();
    final products = widget.p.products.where((product) => needle.isEmpty || '${product['name']}'.toLowerCase().contains(needle) || '${product['barcode'] ?? ''}'.toLowerCase().contains(needle) || '${product['sku'] ?? ''}'.toLowerCase().contains(needle)).toList();
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(children: [
                Expanded(child: TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Search product / barcode', prefixIcon: Icon(Icons.search)))),
                const SizedBox(width: 8),
                FilledButton.icon(onPressed: scanAndAddProduct, icon: const Icon(Icons.document_scanner), label: const Text('Scan')),
              ]),
              const SizedBox(height: 10),
              ...products.map((p) => Card(
                    child: ListTile(
                      onTap: () => addProduct(p),
                      title: Text('${p['name']}'),
                      subtitle: Text('Stock ${p['stock']} • ${p['unit']}'),
                      trailing: Text('NPR ${p['sale_price']}'),
                    ),
                  )),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Row(children: [
                    Icon(Icons.receipt_long),
                    SizedBox(width: 8),
                    Text('Current Bill', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ]),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: cart
                          .map((i) => ListTile(
                                title: Text(i['name']),
                                subtitle: Text('${i['qty']} × ${AppSettingsService.money(i['price'] as num)}'),
                                trailing: Text(AppSettingsService.money(i['total'] as num)),
                              ))
                          .toList(),
                    ),
                  ),
                  Text('Subtotal: ${AppSettingsService.money(subtotal)}'),
                  Text('Discount: ${AppSettingsService.money(discount)}'),
                  TextField(keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Discount amount (${AppSettingsService.currencyCode.value})'), onChanged: (value) => setState(() => discount = double.tryParse(value) ?? 0)),
                  if (discount > 0) Padding(padding: const EdgeInsets.only(top: 8), child: TextField(controller: discountReason, decoration: const InputDecoration(labelText: 'Discount reason / occasion', hintText: 'Festival offer, regular party, goodwill, damaged item'))),
                  Text('Tax (${taxRate.toStringAsFixed(2)}%): ${AppSettingsService.money(tax)}'),
                  Text('Total: ${AppSettingsService.money(total)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Paid: ${AppSettingsService.money(paid)}'),
                  Text('Due: ${AppSettingsService.money(due)}'),
                  if (lastLuckyToken != null) Text('Lucky draw token: $lastLuckyToken', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTaxGroupId,
                    items: [
                      const DropdownMenuItem(value: 'NONE', child: Text('No tax')),
                      ...widget.p.taxGroups.map((group) => DropdownMenuItem(value: '${group['id']}', child: Text('${group['name']} · ${group['rate']}%'))),
                    ],
                    onChanged: (value) {
                      final group = widget.p.taxGroups.where((row) => '${row['id']}' == value).toList();
                      setState(() { selectedTaxGroupId = value ?? 'NONE'; taxRate = group.isEmpty ? 0 : (group.first['rate'] as num).toDouble(); });
                    },
                    decoration: const InputDecoration(labelText: 'Tax group'),
                  ),
                  const SizedBox(height: 8),
                  if (widget.p.taxGroups.isNotEmpty) ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Tax groups'),
                    subtitle: Text('${widget.p.taxGroups.length} active group(s)'),
                    children: widget.p.taxGroups.map((group) => ListTile(dense: true, title: Text('${group['name']}'), subtitle: Text('${group['rate']}%'), trailing: IconButton(icon: const Icon(Icons.archive_outlined), tooltip: 'Archive tax group', onPressed: () => _archiveTaxGroup('${group['id']}')))).toList(),
                  ),
                  Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _addTaxGroup, icon: const Icon(Icons.add), label: const Text('Add tax group'))),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: payment,
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'QR', child: Text('QR')),
                      DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                      DropdownMenuItem(value: 'CREDIT', child: Text('Credit')),
                      DropdownMenuItem(value: 'SPLIT', child: Text('Split payment')),
                    ],
                    onChanged: (v) => setState(() { payment = v!; if (payment != 'SPLIT') paymentTenders = []; }),
                    decoration: const InputDecoration(labelText: 'Payment'),
                  ),
                  const SizedBox(height: 8),
                  if (payment == 'SPLIT') OutlinedButton.icon(onPressed: total <= 0 ? null : _manageSplitTenders, icon: const Icon(Icons.call_split), label: Text(paymentTenders.isEmpty ? 'Add split tenders' : 'Edit split tenders · Paid ${AppSettingsService.money(paid)}'))
                  else TextField(keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Paid amount (${AppSettingsService.currencyCode.value})'), onChanged: (value) => setState(() => paid = double.tryParse(value) ?? 0)),
                  const SizedBox(height: 8),
                  if (hasQrTender) ...[
                    TextField(
                      controller: upiId,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Shop UPI / payment ID', prefixIcon: Icon(Icons.qr_code_2)),
                    ),
                    if (upiId.text.trim().isNotEmpty)
                      Card(
                        color: const Color(0xfff1fbf5),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(children: [
                            const Text('Customer scans this QR. The invoice amount is already filled in.', textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            QrImageView(data: paymentQrData, size: 190, backgroundColor: Colors.white),
                            Text('Exact amount: ${AppSettingsService.money(total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(onPressed: total <= 0 ? null : () => setState(() => paid = total), icon: const Icon(Icons.verified), label: const Text('Mark QR payment received')),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: selectedCustomerId,
                    decoration: const InputDecoration(labelText: 'Customer / party'),
                    hint: const Text('Walk-in customer'),
                    items: widget.p.customers
                        .map((customer) => DropdownMenuItem<String>(value: '${customer['id']}', child: Text('${customer['name']}')))
                        .toList(),
                    onChanged: (value) {
                      selectCustomer(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: customerPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Customer WhatsApp number (optional)',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: save,
                    icon: const Icon(Icons.check),
                    label: const Text('Save & Complete Bill'),
                  ),
                  OutlinedButton.icon(
                    onPressed: cart.isEmpty && lastSavedCart.isEmpty
                        ? null
                        : () async {
                            final saved = cart.isEmpty;
                            final items = saved ? lastSavedCart : cart;
                            final svc = PrintingService();
                            await svc.printA4(
                              invoiceNo: saved ? 'SAVED-${DateTime.now().millisecondsSinceEpoch}' : 'PREVIEW',
                              customer: saved ? lastSavedCustomerName : 'Walk-in Customer',
                              items: items,
                              total: saved ? lastSavedTotal : total,
                              paid: saved ? lastSavedPaid : paid,
                              due: saved ? lastSavedDue : due,
                              discount: saved ? lastSavedDiscount : discount,
                              discountReason: saved ? lastSavedDiscountReason : discountReason.text.trim(),
                              qrStatus: saved ? lastSavedQrStatus : qrStatus,
                              luckyToken: lastLuckyToken,
                            );
                          },
                    icon: const Icon(Icons.print),
                    label: const Text('A4 Preview / Print'),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Customize WhatsApp message'),
                    subtitle: const Text('Use {{customerName}}, {{orderTotal}}, {{items}}, and more'),
                    children: [
                      TextField(
                        controller: whatsappTemplate,
                        minLines: 6,
                        maxLines: 12,
                        decoration: const InputDecoration(labelText: 'Message template', alignLabelWithHint: true, border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 6),
                      Align(alignment: Alignment.centerLeft, child: Text('Supported: ${WhatsAppService.supportedVariables.join('  ')}', style: const TextStyle(fontSize: 11, color: Colors.black54))),
                      const SizedBox(height: 6),
                      Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(onPressed: _saveWhatsAppTemplate, icon: const Icon(Icons.save), label: const Text('Save template'))),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: cart.isEmpty && lastSavedCart.isEmpty ? null : shareWhatsApp,
                    icon: const Icon(Icons.chat),
                    label: const Text('Share detailed WhatsApp summary'),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cloud_sync),
                    title: const Text('Backup & restore'),
                    subtitle: const Text('Share a complete offline JSON backup or restore one from this phone'),
                    children: [
                      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: _exportBackup, icon: const Icon(Icons.ios_share), label: const Text('Export / share backup'))),
                      Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: _restoreBackup, icon: const Icon(Icons.restore), label: const Text('Restore JSON backup'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
