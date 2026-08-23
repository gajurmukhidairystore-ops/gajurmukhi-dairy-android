import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});
  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController controller;
  final address = TextEditingController(text: 'https://www.google.com');
  bool loading = false;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => loading = true),
        onPageFinished: (url) { address.text = url; if (mounted) setState(() => loading = false); },
        onWebResourceError: (_) { if (mounted) setState(() => loading = false); },
      ))
      ..loadRequest(Uri.parse(address.text));
  }

  Future<void> openAddress() async {
    final raw = address.text.trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid website address')));
      return;
    }
    await controller.loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 6), child: Row(children: [
      IconButton(tooltip: 'Back', onPressed: () async { if (await controller.canGoBack()) controller.goBack(); }, icon: const Icon(Icons.arrow_back)),
      IconButton(tooltip: 'Forward', onPressed: () async { if (await controller.canGoForward()) controller.goForward(); }, icon: const Icon(Icons.arrow_forward)),
      Expanded(child: TextField(controller: address, textInputAction: TextInputAction.go, onSubmitted: (_) => openAddress(), decoration: const InputDecoration(labelText: 'Website address', prefixIcon: Icon(Icons.language), isDense: true))),
      IconButton(tooltip: 'Open', onPressed: openAddress, icon: const Icon(Icons.open_in_new)),
      IconButton(tooltip: 'Refresh', onPressed: () => controller.reload(), icon: const Icon(Icons.refresh)),
    ])),
    if (loading) const LinearProgressIndicator(minHeight: 2),
    Expanded(child: WebViewWidget(controller: controller)),
  ]);

  @override
  void dispose() { address.dispose(); super.dispose(); }
}
