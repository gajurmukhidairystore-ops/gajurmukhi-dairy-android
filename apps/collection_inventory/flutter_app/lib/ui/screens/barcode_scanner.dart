import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (handled || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue?.trim();
    if (value == null || value.isEmpty) return;
    handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan product barcode')),
        body: Stack(fit: StackFit.expand, children: [
          MobileScanner(onDetect: _onDetect),
          Center(child: Container(width: 260, height: 160, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(18)))),
          const Positioned(left: 24, right: 24, bottom: 42, child: Card(child: Padding(padding: EdgeInsets.all(12), child: Text('Point the camera at a product barcode. The item will be added directly to the current bill.', textAlign: TextAlign.center)))),
        ]),
      );
}
