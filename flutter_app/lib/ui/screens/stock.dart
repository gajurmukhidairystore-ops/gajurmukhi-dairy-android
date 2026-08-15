import 'package:flutter/material.dart';
import '../../providers/business_provider.dart';

class StockScreen extends StatefulWidget {
  final BusinessProvider p;
  const StockScreen(this.p, {super.key});
  @override State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String filter = 'All';

  Future<void> addProduct() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final stock = TextEditingController();
    final barcode = TextEditingController();
    String category = 'Grocery';
    String unit = 'Unit';
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: const Text('Add inventory item'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Product name')),
        const SizedBox(height: 10),
        TextField(controller: barcode, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Barcode (optional)', prefixIcon: Icon(Icons.qr_code_scanner))),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Sale price'))), const SizedBox(width: 8), Expanded(child: TextField(controller: stock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Opening stock')))]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category'), items: const [DropdownMenuItem(value: 'Grocery', child: Text('Grocery')), DropdownMenuItem(value: 'Dairy', child: Text('Dairy')), DropdownMenuItem(value: 'Household', child: Text('Household')), DropdownMenuItem(value: 'Other', child: Text('Other'))], onChanged: (v) => setDialogState(() => category = v ?? 'Grocery')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: unit, decoration: const InputDecoration(labelText: 'Unit'), items: const [DropdownMenuItem(value: 'Unit', child: Text('Unit')), DropdownMenuItem(value: 'Litre', child: Text('Litre')), DropdownMenuItem(value: 'Kg', child: Text('Kg')), DropdownMenuItem(value: 'Packet', child: Text('Packet'))], onChanged: (v) => setDialogState(() => unit = v ?? 'Unit')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add'))],
    )));
    final priceValue = double.tryParse(price.text) ?? 0;
    final stockValue = double.tryParse(stock.text) ?? 0;
    if (ok == true && name.text.trim().isNotEmpty && priceValue > 0) await widget.p.addProduct(name.text.trim(), priceValue, stockValue, category: category, unit: unit, barcode: barcode.text.trim());
    name.dispose(); price.dispose(); stock.dispose(); barcode.dispose();
  }

  Future<void> recordReturnForProduct(Map<String, Object?> product) async {
    final qty = TextEditingController();
    final amount = TextEditingController();
    String type = 'SALE_RETURN';
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text('Return ${product['name']}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: type, decoration: const InputDecoration(labelText: 'Return type'), items: const [DropdownMenuItem(value: 'SALE_RETURN', child: Text('Sales return (customer)')), DropdownMenuItem(value: 'PURCHASE_RETURN', child: Text('Purchase return (supplier)'))], onChanged: (v) => setDialogState(() => type = v ?? 'SALE_RETURN')),
        const SizedBox(height: 10),
        TextField(controller: qty, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity')),
        const SizedBox(height: 10),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Return amount (NPR)')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save return'))],
    )));
    final qtyValue = double.tryParse(qty.text.trim()) ?? 0;
    final amountValue = double.tryParse(amount.text.trim()) ?? 0;
    if (ok == true && qtyValue > 0) {
      try {
        await widget.p.recordReturn(type: type, productId: '${product['id']}', qty: qtyValue, amount: amountValue, note: type == 'SALE_RETURN' ? 'Customer sales return' : 'Supplier purchase return');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Return saved and stock updated')));
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save return: $error')));
      }
    }
    qty.dispose(); amount.dispose();
  }

  Future<void> adjust(Map<String, Object?> product) async {
    final amount = TextEditingController();
    String direction = 'IN';
    final ok = await showDialog<bool>(context: context, builder: (_) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
      title: Text('Adjust ${product['name']} stock'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: direction, items: const [DropdownMenuItem(value: 'IN', child: Text('Add stock / purchase')), DropdownMenuItem(value: 'OUT', child: Text('Remove stock / damage'))], onChanged: (v) => setDialogState(() => direction = v ?? 'IN')),
        const SizedBox(height: 10),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save'))],
    )));
    final value = double.tryParse(amount.text) ?? 0;
    if (ok == true && value > 0) await widget.p.adjustStock('${product['id']}', direction == 'IN' ? value : -value, direction == 'IN' ? 'Stock received' : 'Stock removed');
    amount.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = widget.p.products.where((product) => filter == 'All' || '${product['category']}' == filter).toList();
    return Scaffold(
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [const Expanded(child: Text('Inventory', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: addProduct, icon: const Icon(Icons.add_box), label: const Text('Add item'))]),
        const SizedBox(height: 4),
        const Text('Manage grocery, dairy, household, and other shop products.'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Grocery', 'Dairy', 'Household', 'Other'].map((value) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(value), selected: filter == value, onSelected: (_) => setState(() => filter = value)),
            )).toList(),
          ),
        ),
        const SizedBox(height: 12),
        ...products.map((x) {
          final stock = (x['stock'] as num?)?.toDouble() ?? 0;
          final low = (x['low_stock'] as num?)?.toDouble() ?? 5;
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon('${x['category']}' == 'Grocery' ? Icons.shopping_basket : Icons.local_drink)),
              title: Text('${x['name']}'),
              subtitle: Text('${x['category']} • ${x['unit']} • Sale NPR ${x['sale_price']}${'${x['barcode']}'.trim().isEmpty ? '' : ' • Barcode ${x['barcode']}'}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(stock.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)), Text(stock <= low ? 'LOW STOCK' : 'OK', style: TextStyle(color: stock <= low ? Colors.orange : Colors.green))]), IconButton(tooltip: 'Sales or purchase return', icon: const Icon(Icons.assignment_return_outlined), onPressed: () => recordReturnForProduct(x)]),
              onTap: () => adjust(x),
            ),
          );
        }),
        if (products.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No products in this category yet.')),
      ]),
    );
  }
}
