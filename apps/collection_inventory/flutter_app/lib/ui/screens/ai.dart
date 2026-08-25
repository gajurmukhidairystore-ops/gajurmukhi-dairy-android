import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/business_provider.dart';
import '../../app_profile.dart';
import '../../services/ai_service.dart';
import '../../services/ai_command_service.dart';
import '../../services/mobile_cloud_service.dart';

class AiScreen extends StatefulWidget {
  final BusinessProvider p;
  final String role;
  const AiScreen(this.p, {super.key, this.role = 'admin'});
  @override State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final q = TextEditingController();
  final command = TextEditingController();
  final socialPrompt = TextEditingController();
  String answer = 'Ask about sales, stock, customer dues, expenses, milk collection, or product performance.';
  String commandAnswer = AiCommandService.supportedCommands;
  AiCommandResult? pendingCommand;
  bool busy = false;
  bool commandBusy = false;
  bool socialBusy = false;
  String socialChannel = 'facebook';
  SocialMediaDraft? socialDraft;
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  List<String> get prompts {
    if (AppProfile.current.kind == GajurmukhiAppKind.customer || widget.role == 'customer') return ['Where is my order?', 'What is available today?', 'How do I pay by QR?', 'Show my recent orders'];
    if (AppProfile.current.kind == GajurmukhiAppKind.store || widget.role == 'shop') return ['Summarize today’s sales', 'What should I restock?', 'Which bills are unpaid?', 'Show pending orders'];
    if (widget.role == 'collector') return ['How much milk came in?', 'Which collection is missing?', 'Summarize FAT and SNF', 'What should I check next?'];
    return ['Summarize today', 'What should I restock?', 'Who has outstanding dues?', 'How much milk came in?'];
  }

  Future<void> _runCommand({bool confirmed = false}) async {
    if (command.text.trim().isEmpty || commandBusy) return;
    setState(() => commandBusy = true);
    try {
      final result = await AiCommandService().execute(command: command.text, role: widget.role, confirmed: confirmed);
      if (mounted) setState(() { commandAnswer = result.message; pendingCommand = result.requiresConfirmation ? result : null; commandBusy = false; });
    } catch (error) {
      if (mounted) setState(() { commandAnswer = 'Command could not be applied: $error'; pendingCommand = null; commandBusy = false; });
    }
  }

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

  Future<void> _generateSocialDraft() async {
    if (widget.role != 'admin') return;
    final prompt = socialPrompt.text.trim();
    if (prompt.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Describe the promotion in at least 8 characters.')));
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Generate social-media draft?'),
      content: const Text('This sends your promotion description to the secure cloud image and caption services. One image and caption draft will be generated; nothing will be posted automatically.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Generate'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => socialBusy = true);
    try {
      final draft = await MobileCloudService().generateSocialMediaDraft(channel: socialChannel, prompt: prompt);
      if (mounted) setState(() => socialDraft = draft);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate draft: $error')));
    }
    if (mounted) setState(() => socialBusy = false);
  }

  Future<void> _shareSocialDraft() async {
    final draft = socialDraft;
    if (draft == null) return;
    await Share.share('${draft.caption}\n\nGenerated image: ${draft.imageUrl}');
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Text('${AppProfile.current.name} AI Assistant', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Text('Ask in English or Nepali. The assistant receives only the controlled business snapshot.'),
    const SizedBox(height: 14),
    Wrap(spacing: 8, runSpacing: 8, children: prompts.map((prompt) => ActionChip(label: Text(prompt), onPressed: () { q.text = prompt; })).toList()),
    const SizedBox(height: 14),
    TextField(controller: q, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Ask your business AI')),
    const SizedBox(height: 10),
    FilledButton.icon(onPressed: busy ? null : _ask, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome), label: Text(busy ? 'Analyzing…' : 'Analyze')),
    const SizedBox(height: 14),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(answer))),
    if (widget.role == 'admin') ...[
      const SizedBox(height: 18),
      Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AI Social Media Studio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text('Create a reviewable image-and-caption draft for Facebook, Instagram, WhatsApp Status, or another channel. It does not post anything automatically.'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: socialChannel, decoration: const InputDecoration(labelText: 'Channel'), items: const [DropdownMenuItem(value: 'facebook', child: Text('Facebook')), DropdownMenuItem(value: 'instagram', child: Text('Instagram')), DropdownMenuItem(value: 'whatsapp_status', child: Text('WhatsApp Status')), DropdownMenuItem(value: 'other', child: Text('Other social media'))], onChanged: socialBusy ? null : (value) => setState(() => socialChannel = value ?? socialChannel)),
          const SizedBox(height: 10),
          TextField(controller: socialPrompt, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Promotion details', hintText: 'Example: Fresh morning milk delivery for Dashain week')),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: socialBusy ? null : _generateSocialDraft, icon: socialBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.image_outlined), label: Text(socialBusy ? 'Generating image and caption…' : 'Generate draft')),
          if (socialDraft != null) ...[
            const Divider(height: 28),
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(socialDraft!.imageUrl, height: 240, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 100, child: Center(child: Text('Generated image link could not be displayed. You can still share it.')))),
            const SizedBox(height: 10),
            SelectableText(socialDraft!.caption),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _shareSocialDraft, icon: const Icon(Icons.share), label: const Text('Share draft to social app')),
          ],
        ])),
      ),
    ],
    const SizedBox(height: 18),
    Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AI settings commands', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text('Commands are limited to approved settings. Sensitive changes require confirmation and Admin permission.'),
          const SizedBox(height: 10),
          TextField(controller: command, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Type a command', hintText: 'Example: set theme to dark')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: commandBusy ? null : () => _runCommand(), icon: commandBusy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow), label: Text(commandBusy ? 'Applying…' : 'Run command'))),
            if (pendingCommand != null) ...[
              const SizedBox(width: 8),
              OutlinedButton(onPressed: commandBusy ? null : () => _runCommand(confirmed: true), child: const Text('Confirm')),
            ],
          ]),
          const SizedBox(height: 10),
          Text(commandAnswer),
        ]),
      ),
    ),
  ]);

  @override
  void dispose() { q.dispose(); command.dispose(); socialPrompt.dispose(); super.dispose(); }
}
