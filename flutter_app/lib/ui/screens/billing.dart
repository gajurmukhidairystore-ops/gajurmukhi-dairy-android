import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/business_provider.dart';
import '../../services/printing_service.dart';
import '../../services/whatsapp_service.dart';

class BillingScreen extends StatefulWidget {
  final BusinessProvider p;
  const BillingScreen(this.p, {super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final search = TextEditingController();
  final customerPhone = TextEditingController();
  final upiId = TextEditingController();
  final List<Map<String, dynamic>> cart = [];
  String payment = 'CASH';
  double discount = 0;
  double paid = 0;
  String? selectedCustomerId;

  double get subtotal => cart.fold(0, (s, i) => s + (i['total'] as num).toDouble());
  double get total => (subtotal - discount).clamp(0, double.infinity);
  double get due => (total - paid).clamp(0, double.infinity).toDouble();

  String get qrStatus => payment == 'QR' ? (paid >= total && total > 0 ? 'received' : 'pending') : 'not_applicable';

  String get paymentQrData => 'upi://pay?pa=${Uri.encodeComponent(upiId.text.trim())}&pn=${Uri.encodeComponent('Gajurmukhi Dairy & Store')}&am=${total.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent('Gajurmukhi bill')}';

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
    super.dispose();
  }

  void addProduct(Map<String, Object?> product) {
    final price = (product['sale_price'] as num).toDouble();
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

  Future<void> save() async {
    if (cart.isEmpty) return;
    await widget.p.createInvoice(
      customerId: selectedCustomerId,
      items: cart,
      discount: discount,
      paid: paid,
      paymentMethod: payment,
      qrStatus: qrStatus,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice saved')));
    setState(() => cart.clear());
  }

  Future<void> shareWhatsApp() async {
    if (cart.isEmpty) return;
    final invoiceNumber = 'DRAFT-${DateTime.now().millisecondsSinceEpoch}';
    final message = WhatsAppService.dailyTransactionMessage(
      invoiceNumber: invoiceNumber,
      date: DateTime.now(),
      customerName: '${customerById(selectedCustomerId)?['name'] ?? 'Walk-in Customer'}',
      customerPhone: customerPhone.text.trim().isEmpty ? null : customerPhone.text.trim(),
      items: cart.map((item) => <String, Object?>{
        'name': item['name'],
        'quantity': item['qty'],
        'unitPrice': item['price'],
      }).toList(),
      subtotal: subtotal,
      discount: discount,
      total: total,
      paid: paid,
      due: due,
      paymentMethod: payment,
      upiId: upiId.text.trim().isEmpty ? null : upiId.text.trim(),
      qrStatus: qrStatus,
    );
    await WhatsAppService().openMessage(customerPhone.text.trim(), message);
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.p.products;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: search,
                decoration: const InputDecoration(
                  labelText: 'Search product / barcode',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
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
                                subtitle: Text('${i['qty']} × NPR ${i['price']}'),
                                trailing: Text('NPR ${i['total']}'),
                              ))
                          .toList(),
                    ),
                  ),
                  Text('Subtotal: NPR ${subtotal.toStringAsFixed(2)}'),
                  Text('Discount: NPR ${discount.toStringAsFixed(2)}'),
                  Text('Total: NPR ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Paid: NPR ${paid.toStringAsFixed(2)}'),
                  Text('Due: NPR ${due.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: payment,
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'QR', child: Text('QR')),
                      DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                      DropdownMenuItem(value: 'CREDIT', child: Text('Credit')),
                    ],
                    onChanged: (v) => setState(() => payment = v!),
                    decoration: const InputDecoration(labelText: 'Payment'),
                  ),
                  const SizedBox(height: 8),
                  if (payment == 'QR') ...[
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
                            Text('Exact amount: NPR ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      final customer = customerById(value);
                      setState(() {
                        selectedCustomerId = value;
                        customerPhone.text = '${customer?['phone'] ?? ''}';
                      });
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
                    onPressed: cart.isEmpty
                        ? null
                        : () async {
                            final svc = PrintingService();
                            await svc.printA4(
                              invoiceNo: 'PREVIEW',
                              customer: 'Walk-in Customer',
                              items: cart,
                              total: total,
                              paid: paid,
                              due: due,
                              qrStatus: qrStatus,
                            );
                          },
                    icon: const Icon(Icons.print),
                    label: const Text('A4 Preview / Print'),
                  ),
                  OutlinedButton.icon(
                    onPressed: cart.isEmpty ? null : shareWhatsApp,
                    icon: const Icon(Icons.chat),
                    label: const Text('Share detailed WhatsApp summary'),
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
