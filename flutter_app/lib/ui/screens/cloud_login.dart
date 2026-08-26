import 'package:flutter/material.dart';

import '../../services/local_auth_service.dart';
import '../../services/mobile_cloud_service.dart';

class CloudLoginScreen extends StatefulWidget {
  final LocalAuthService auth;
  final ValueChanged<LocalSession> onLoggedIn;
  final bool allowRegistration;
  const CloudLoginScreen({super.key, required this.auth, required this.onLoggedIn, this.allowRegistration = false});

  @override State<CloudLoginScreen> createState() => _CloudLoginScreenState();
}

class _CloudLoginScreenState extends State<CloudLoginScreen> {
  final workspace = TextEditingController(text: 'Gajurmukhi Dairy & Store');
  final name = TextEditingController();
  final username = TextEditingController();
  final pin = TextEditingController();
  final cloud = MobileCloudService();
  bool createAdmin = false;
  bool busy = false;
  String? error;

  Future<void> submit() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final session = createAdmin
          ? await cloud.registerAdmin(workspaceName: workspace.text, displayName: name.text, username: username.text, pin: pin.text)
          : await cloud.login(username: username.text, pin: pin.text);
      final local = await widget.auth.login(username.text, pin.text) ?? await widget.auth.createUser(name: session.account.displayName, username: session.account.username, pin: pin.text, role: session.account.role);
      if (!mounted) return;
      widget.onLoggedIn(local);
    } catch (value) {
      if (mounted) setState(() { error = '$value'.replaceFirst('Bad state: ', ''); busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shared cloud sign in')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.cloud_sync_outlined, size: 56),
        const SizedBox(height: 12),
        const Text('One app, shared business data', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Use your assigned username and PIN. Your role controls the data and actions available to you.', textAlign: TextAlign.center),
        if (widget.allowRegistration) SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: createAdmin,
          onChanged: busy ? null : (value) => setState(() => createAdmin = value),
          title: const Text('Create the first cloud Admin'),
          subtitle: const Text('Use only once for the business owner.'),
        ),
        if (createAdmin) ...[
          TextField(controller: workspace, decoration: const InputDecoration(labelText: 'Business / workspace name')),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Admin display name')),
          const SizedBox(height: 12),
        ],
        TextField(controller: username, autocorrect: false, decoration: const InputDecoration(labelText: 'Username')),
        const SizedBox(height: 12),
        TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN (4–12 digits)')),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: busy ? null : submit, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: Text(busy ? 'Checking…' : createAdmin ? 'Create cloud Admin' : 'Sign in and sync')),
      ]),
    )),
  );

  @override
  void dispose() { workspace.dispose(); name.dispose(); username.dispose(); pin.dispose(); super.dispose(); }
}
