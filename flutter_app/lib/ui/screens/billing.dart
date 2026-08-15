import 'package:flutter/material.dart';
import '../../providers/business_provider.dart';
import '../../services/printing_service.dart';

class BillingScreen extends StatefulWidget {
  final BusinessProvider p;
  const BillingScreen(this.p, {super.key});
  @override State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  final search = TextEditingController();
  final List<Map<String,dynamic>> cart = [];
  String payment = 'CASH';
  double discount = 0;
  double paid = 0;

  double get subtotal => cart.fold(0, (s,i) => s + (i['total'] as num).toDouble());
  double get total => (subtotal - discount).clamp(0, double.infinity);
  double get due => total - paid;

  void addProduct(Map<String,Object?> product) {
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
      customerId: null,
      items: cart,
      discount: discount,
      paid: paid,
      paymentMethod: payment,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice saved')));
    setState(() => cart.clear());
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
                    Icon(Icons.receipt_long), SizedBox(width: 8),
                    Text('Current Bill', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
                  ]),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: cart.map((i) => ListTile(
                        title: Text(i['name']),
                        subtitle: Text('${i['qty']} × NPR ${i['price']}'),
                        trailing: Text('NPR ${i['total']}'),
                      )).toList(),
                    ),
                  ),
                  Text('Subtotal: NPR ${subtotal.toStringAsFixed(2)}'),
                  Text('Discount: NPR ${discount.toStringAsFixed(2)}'),
                  Text('Total: NPR ${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                  FilledButton.icon(
                    onPressed: save,
                    icon: const Icon(Icons.check),
                    label: const Text('Save & Complete Bill'),
                  ),
                  OutlinedButton.icon(
                    onPressed: cart.isEmpty ? null : () async {
                      final svc = PrintingService();
                      await svc.printA4(
                        invoiceNo: 'PREVIEW',
                        customer: 'Walk-in Customer',
                        items: cart,
                        total: total,
                        paid: paid,
                        due: due,
                      );
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('A4 Preview / Print'),
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
