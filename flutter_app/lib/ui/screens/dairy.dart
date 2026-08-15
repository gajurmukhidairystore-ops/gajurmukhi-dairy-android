import 'package:flutter/material.dart';
import '../../providers/business_provider.dart';

class DairyScreen extends StatefulWidget {
  final BusinessProvider p;
  const DairyScreen(this.p, {super.key});
  @override State<DairyScreen> createState() => _DairyScreenState();
}

class _DairyScreenState extends State<DairyScreen> {
  String? farmerId;
  final litres = TextEditingController();
  final fat = TextEditingController(text: '3.5');
  final snf = TextEditingController(text: '6.5');
  final rate = TextEditingController(text: '65');
  String shift = 'MORNING';

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('Milk Collection', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: farmerId,
        items: widget.p.farmers.map((f) => DropdownMenuItem(
          value: '${f['id']}', child: Text('${f['name']}'),
        )).toList(),
        onChanged: (v) => setState(() => farmerId = v),
        decoration: const InputDecoration(labelText: 'Farmer'),
      ),
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
        onPressed: farmerId == null ? null : () async {
          await widget.p.addMilkCollection(
            farmerId: farmerId!,
            litres: double.tryParse(litres.text) ?? 0,
            fat: double.tryParse(fat.text) ?? 0,
            snf: double.tryParse(snf.text) ?? 0,
            rate: double.tryParse(rate.text) ?? 0,
            shift: shift,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Milk collection recorded')));
        },
        icon: const Icon(Icons.save),
        label: const Text('Save Collection'),
      ),
      const Divider(height: 30),
      const Text('Today’s Collection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ...widget.p.milk.map((m) => ListTile(
        title: Text('${m['litres']} L • FAT ${m['fat']} • SNF ${m['snf']}'),
        subtitle: Text('${m['shift']} • Rate NPR ${m['rate']}'),
        trailing: Text('NPR ${m['amount']}'),
      )),
    ],
  );
}
