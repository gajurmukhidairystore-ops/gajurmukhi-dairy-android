import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/business_provider.dart';
import 'screens/dashboard.dart';
import 'screens/billing.dart';
import 'screens/customers.dart';
import 'screens/stock.dart';
import 'screens/dairy.dart';
import 'screens/reports.dart';
import 'screens/ai.dart';

class GajurmukhiApp extends StatelessWidget {
  final bool supabaseEnabled;
  const GajurmukhiApp({super.key, this.supabaseEnabled = false});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Gajurmukhi Smart Business',
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.green,
      brightness: Brightness.light,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: supabaseEnabled ? const AuthScreen() : const MainShell(),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;
  Future<void> _signIn() async {
    setState(() { busy = true; error = null; });
    try { await AuthService().signIn(email.text.trim(), password.text); if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell())); }
    catch (_) { if (mounted) setState(() => error = 'Sign-in failed. Check your email, password, and connection.'); }
    if (mounted) setState(() => busy = false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_drink, size: 48),
                  const SizedBox(height: 12),
                  const Text('Gajurmukhi Dairy & Store', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                  if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: busy ? null : _signIn, child: Text(busy ? 'Signing in…' : 'Sign in')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BusinessProvider>();
    final screens = [
      DashboardScreen(p),
      BillingScreen(p),
      CustomersScreen(p),
      StockScreen(p),
      DairyScreen(p),
      ReportsScreen(p),
      AiScreen(p),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gajurmukhi Dairy & Store'),
        actions: [
          IconButton(onPressed: p.refresh, icon: const Icon(Icons.sync)),
          PopupMenuButton<String>(
            onSelected: (_) {},
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'users', child: Text('Users & Roles')),
              PopupMenuItem(value: 'backup', child: Text('Backup & Cloud')),
            ],
          ),
        ],
      ),
      body: screens[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Billing'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Ledger'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Stock'),
          NavigationDestination(icon: Icon(Icons.local_drink), label: 'Dairy'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'AI'),
        ],
      ),
    );
  }
}
