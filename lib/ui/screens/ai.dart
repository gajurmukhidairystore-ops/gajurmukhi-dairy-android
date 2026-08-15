import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/business_provider.dart';
import '../../services/ai_service.dart';

class AiScreen extends StatefulWidget {
  final BusinessProvider p;
  const AiScreen(this.p, {super.key});
  @override State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final q = TextEditingController();
  String answer = 'Ask about sales, stock, customer dues, expenses, milk collection, or product performance.';
  bool busy = false;
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  Future<void> _ask() async {
    final question = q.text.trim();
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (question.isEmpty) { setState(() => answer = 'Enter a question first.'); return; }
    if (apiBaseUrl.isEmpty || token == null) { setState(() => answer = 'AI requires a signed-in session and API_BASE_URL configuration. The question was not sent.'); return; }
    setState(() { busy = true; answer = 'Reviewing your business snapshot…'; });
    try {
      final result = await AiBusinessService(baseUrl: apiBaseUrl, authToken: token).ask(question: question, businessSnapshot: widget.p.totals);
      if (mounted) setState(() => answer = result);
    } catch (error) { if (mounted) setState(() => answer = 'The AI service is unavailable. Check connectivity and try again.'); }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('AI Business Assistant', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Text('Ask in English or Nepali. The assistant receives only the controlled business snapshot.'),
    const SizedBox(height: 14),
    Wrap(spacing: 8, runSpacing: 8, children: ['Summarize today', 'What should I restock?', 'Who has outstanding dues?', 'How much milk came in?'].map((prompt) => ActionChip(label: Text(prompt), onPressed: () { q.text = prompt; })).toList()),
    const SizedBox(height: 14),
    TextField(controller: q, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Ask your business AI')),
    const SizedBox(height: 10),
    FilledButton.icon(onPressed: busy ? null : _ask, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome), label: Text(busy ? 'Analyzing…' : 'Analyze')),
    const SizedBox(height: 14),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(answer))),
  ]);

  @override
  void dispose() { q.dispose(); super.dispose(); }
}
