import 'package:flutter/material.dart';
import '../../providers/business_provider.dart';

class StockScreen extends StatelessWidget {
  final BusinessProvider p;
  const StockScreen(this.p, {super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: p.products.map((x) {
        final stock = (x['stock'] as num).toDouble();
        final low = (x['low_stock'] as num).toDouble();
        return Card(
          child: ListTile(
            leading: const Icon(Icons.inventory_2),
            title: Text('${x['name']}'),
            subtitle: Text('${x['category']} • ${x['unit']} • Sale NPR ${x['sale_price']}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${x['stock']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(stock <= low ? 'LOW STOCK' : 'OK',
                  style: TextStyle(color: stock <= low ? Colors.orange : Colors.green)),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );
}
