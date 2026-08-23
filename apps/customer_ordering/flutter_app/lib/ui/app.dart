import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../app_profile.dart';
import '../providers/business_provider.dart';
import '../services/auth_service.dart';
import '../services/local_auth_service.dart';
import '../services/role_permissions.dart';
import 'screens/ai.dart';
import 'screens/billing.dart';
import 'screens/browser.dart';
import 'screens/customers.dart';
import 'screens/dashboard.dart';
import 'screens/dairy.dart';
import 'screens/expenses.dart';
import 'screens/games.dart';
import 'screens/music.dart';
import 'screens/orders.dart';
import 'screens/lucky_draw.dart';
import 'screens/reports.dart';
import 'screens/stock.dart';
import 'screens/users.dart';

class GajurmukhiApp extends StatelessWidget {
  final bool supabaseEnabled;
  const GajurmukhiApp({super.key, this.supabaseEnabled = false});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppProfile.current.name,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xff1976e8),
          brightness: Brightness.light,
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        ),
        home: supabaseEnabled ? const AuthScreen() : LocalAuthGate(db: context.read<BusinessProvider>().db),
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
    try {
      await AuthService().signIn(email.text.trim(), password.text);
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell(session: LocalSession(id: 'supabase', name: 'Cloud user', username: 'cloud', role: 'admin'))));
    } catch (_) {
      if (mounted) setState(() => error = 'Sign-in failed. Check your email, password, and connection.');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/gajurmukhi-app-logo.png', width: 148, height: 74, fit: BoxFit.contain)),
                    const SizedBox(height: 12),
                    Text(AppProfile.current.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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

  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }
}

class LocalAuthGate extends StatefulWidget {
  final AppDatabase db;
  const LocalAuthGate({super.key, required this.db});
  @override State<LocalAuthGate> createState() => _LocalAuthGateState();
}

class _LocalAuthGateState extends State<LocalAuthGate> {
  late final LocalAuthService auth = LocalAuthService(widget.db);
  bool? hasUsers;

  @override
  void initState() {
    super.initState();
    auth.hasUsers().then((value) { if (mounted) setState(() => hasUsers = value); });
  }

  @override
  Widget build(BuildContext context) {
    if (hasUsers == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (hasUsers == false) return SetupAdminScreen(auth: auth, onCreated: (session) => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainShell(session: session))));
    return RoleLoginScreen(auth: auth, onLoggedIn: (session) => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MainShell(session: session))));
  }
}

class SetupAdminScreen extends StatefulWidget {
  final LocalAuthService auth;
  final ValueChanged<LocalSession> onCreated;
  const SetupAdminScreen({super.key, required this.auth, required this.onCreated});
  @override State<SetupAdminScreen> createState() => _SetupAdminScreenState();
}

class _SetupAdminScreenState extends State<SetupAdminScreen> {
  final name = TextEditingController();
  final username = TextEditingController(text: 'admin');
  final pin = TextEditingController();
  String? error;

  Future<void> create() async {
    try {
      final session = await widget.auth.createUser(name: name.text, username: username.text, pin: pin.text, role: 'admin');
      widget.onCreated(session);
    } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Invalid argument(s): ', '')); }
  }

  @override
  Widget build(BuildContext context) => _AuthCard(
        title: 'Set up your dairy',
        subtitle: 'Create the first Admin account. You can add Shop and Collector users after signing in.',
        fields: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Owner name')),
          const SizedBox(height: 12),
          TextField(controller: username, decoration: const InputDecoration(labelText: 'Admin username')),
          const SizedBox(height: 12),
          TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN (minimum 4 digits)')),
        ],
        error: error,
        action: FilledButton(onPressed: create, child: const Text('Create Admin account')),
      );

  @override void dispose() { name.dispose(); username.dispose(); pin.dispose(); super.dispose(); }
}

class RoleLoginScreen extends StatefulWidget {
  final LocalAuthService auth;
  final ValueChanged<LocalSession> onLoggedIn;
  const RoleLoginScreen({super.key, required this.auth, required this.onLoggedIn});
  @override State<RoleLoginScreen> createState() => _RoleLoginScreenState();
}

class _RoleLoginScreenState extends State<RoleLoginScreen> {
  final username = TextEditingController();
  final pin = TextEditingController();
  String? error;

  Future<void> login() async {
    final session = await widget.auth.login(username.text, pin.text);
    if (session == null) { if (mounted) setState(() => error = 'Incorrect username or PIN.'); return; }
    widget.onLoggedIn(session);
  }

  @override
  Widget build(BuildContext context) => _AuthCard(
        title: 'Sign in to Gajurmukhi',
        subtitle: 'Use your assigned Admin, Shop, or Collector account.',
        fields: [
          TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: 12),
          TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN')),
        ],
        error: error,
        action: FilledButton(onPressed: login, child: const Text('Sign in')),
      );

  @override void dispose() { username.dispose(); pin.dispose(); super.dispose(); }
}

class _AuthCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> fields;
  final String? error;
  final Widget action;
  const _AuthCard({required this.title, required this.subtitle, required this.fields, required this.error, required this.action});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/gajurmukhi-app-logo.png', width: 148, height: 74, fit: BoxFit.contain)),
                    const SizedBox(height: 14),
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 22),
                    ...fields,
                    if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
                    const SizedBox(height: 18),
                    action,
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class MainShell extends StatefulWidget {
  final LocalSession session;
  const MainShell({super.key, required this.session});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  bool canAccess(int destination) => RolePermissions.canAccess(widget.session.role, destination);

  void navigate(int destination) {
    if (!canAccess(destination)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your role does not have access to this area.')));
      return;
    }
    setState(() => index = destination);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BusinessProvider>();
    final screens = [
      DashboardScreen(p, onNavigate: navigate),
      BillingScreen(p),
      CustomersScreen(p),
      StockScreen(p),
      DairyScreen(p, role: widget.session.role),
      ReportsScreen(p),
      AiScreen(p, role: widget.session.role),
      ExpensesScreen(p),
      GamesScreen(role: widget.session.role),
      MusicScreen(role: widget.session.role),
      LuckyDrawScreen(role: widget.session.role),
      OrdersScreen(p, role: widget.session.role, currentUserId: widget.session.username),
      const BrowserScreen(),
    ];
    const navigationTargets = [0, 5, 2, 4, 7];
    final selectedNavigationIndex = navigationTargets.indexOf(index);
    final activeScreen = canAccess(index) ? screens[index] : DashboardScreen(p, onNavigate: navigate);
    return Scaffold(
      appBar: index == 0 ? null : AppBar(
        title: Text('${AppProfile.current.name} · ${widget.session.role.toUpperCase()}'),
        actions: [
          IconButton(onPressed: p.refresh, icon: const Icon(Icons.sync)),
              PopupMenuButton<String>(
                onSelected: (value) { if (value == 'games') navigate(8); if (value == 'music') navigate(9); if (value == 'lucky_draw') navigate(10); if (value == 'orders') navigate(11); if (value == 'browser') navigate(12); if (value == 'logout') Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LocalAuthGate(db: p.db)), (_) => false); if (value == 'users' && widget.session.role == 'admin') Navigator.of(context).push(MaterialPageRoute(builder: (_) => UsersScreen(p.db))); },
              itemBuilder: (_) => [
              const PopupMenuItem(value: 'games', child: Text('Daily progress & rewards')),
              const PopupMenuItem(value: 'music', child: Text('YouTube Music')),
                if (widget.session.role == 'admin') const PopupMenuItem(value: 'users', child: Text('Users & Roles')),
              if (widget.session.role == 'admin' || widget.session.role == 'shop' || widget.session.role == 'customer') const PopupMenuItem(value: 'lucky_draw', child: Text('Monthly Lucky Draw')),
              if (widget.session.role == 'admin' || widget.session.role == 'shop' || widget.session.role == 'customer') const PopupMenuItem(value: 'orders', child: Text('Orders & Reminders')),
              if (widget.session.role == 'admin' || widget.session.role == 'shop' || widget.session.role == 'collector' || widget.session.role == 'customer') const PopupMenuItem(value: 'browser', child: Text('In-app browser')),
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: activeScreen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedNavigationIndex < 0 ? 0 : selectedNavigationIndex,
        onDestinationSelected: (i) => navigate(navigationTargets[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_filled), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.person_add_alt_1), label: 'Parties'),
          NavigationDestination(icon: Icon(Icons.local_drink), label: 'Dairy'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'More'),
        ],
      ),
    );
  }
}
