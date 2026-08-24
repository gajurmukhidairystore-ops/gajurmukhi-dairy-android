import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../services/local_auth_service.dart';
import '../../services/mobile_cloud_service.dart';

class UsersScreen extends StatefulWidget {
  final AppDatabase db;
  const UsersScreen(this.db, {super.key});
  @override State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final LocalAuthService auth = LocalAuthService(widget.db);
  List<Map<String, Object?>> users = [];

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    final rows = await widget.db.query('users', where: 'active=1');
    if (mounted) setState(() => users = rows);
  }

  Future<void> addUser() async {
    final name = TextEditingController();
    final username = TextEditingController();
    final pin = TextEditingController();
    String role = 'shop';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Add team login'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 10),
          TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: 10),
          TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN (minimum 4 digits)')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: role, decoration: const InputDecoration(labelText: 'Role'), items: const [DropdownMenuItem(value: 'shop', child: Text('Shop')), DropdownMenuItem(value: 'collector', child: Text('Collector')), DropdownMenuItem(value: 'customer', child: Text('Customer')), DropdownMenuItem(value: 'admin', child: Text('Admin'))], onChanged: (value) => setDialogState(() => role = value ?? 'shop')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create'))],
      )),
    );
    if (ok == true) {
      try {
        await MobileCloudService().createUser(displayName: name.text, username: username.text, pin: pin.text, role: role);
        await auth.createUser(name: name.text, username: username.text, pin: pin.text, role: role);
        await load();
      } catch (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create shared role login: $error')));
      }
    }
    name.dispose(); username.dispose(); pin.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Users & roles')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Team access', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Create shared role logins so each person sees only the work they need. Sign in to the shared cloud as Admin first.'),
          const SizedBox(height: 16),
          ...users.map((user) => Card(child: ListTile(leading: CircleAvatar(child: Text('${user['name']}'.trim().isEmpty ? '?' : '${user['name']}'.trim()[0].toUpperCase())), title: Text('${user['name']}'), subtitle: Text('@${user['username']}'), trailing: Chip(label: Text('${user['role']}'))))),
        ]),
        floatingActionButton: FloatingActionButton.extended(onPressed: addUser, icon: const Icon(Icons.person_add), label: const Text('Add user')),
      );
}
