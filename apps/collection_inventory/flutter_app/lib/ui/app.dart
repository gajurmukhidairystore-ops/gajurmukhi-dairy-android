import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database.dart';
import '../app_profile.dart';
import '../providers/business_provider.dart';
import '../services/auth_service.dart';
import '../services/ai_command_service.dart';
import '../services/mobile_cloud_service.dart';
import '../services/local_auth_service.dart';
import '../services/role_permissions.dart';
import '../services/sync_coordinator.dart';
import 'screens/ai.dart';
import 'screens/billing.dart';
import 'screens/barcode_scanner.dart';
import 'screens/browser.dart';
import 'screens/cloud_login.dart';
import 'screens/customers.dart';
import 'screens/dashboard.dart';
import 'screens/dairy.dart';
import 'screens/expenses.dart';
import 'screens/games.dart';
import 'screens/music.dart';
import 'screens/orders.dart';
import 'screens/lucky_draw.dart';
import 'screens/loans.dart';
import 'screens/reports.dart';
import 'screens/stock.dart';
import 'screens/users.dart';

class GajurmukhiApp extends StatelessWidget {
  final bool supabaseEnabled;
  const GajurmukhiApp({super.key, this.supabaseEnabled = false});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: AppSettingsService.themeMode,
        builder: (context, mode, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppProfile.current.name,
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xff1976e8),
            brightness: Brightness.light,
            inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xff1976e8),
            brightness: Brightness.dark,
            inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
          ),
          home: supabaseEnabled ? const AuthScreen() : LocalAuthGate(db: context.read<BusinessProvider>().db),
        ),
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
        action: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton(onPressed: create, child: const Text('Create offline Admin account')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CloudLoginScreen(auth: widget.auth, allowRegistration: true, onLoggedIn: widget.onCreated))),
            icon: const Icon(Icons.cloud_outlined),
            label: const Text('Use shared cloud account / create first Admin'),
          ),
        ]),
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
  bool biometricAvailable = false;
  bool savedBiometric = false;
  bool rememberBiometric = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final available = await widget.auth.isBiometricAvailable();
    final saved = await widget.auth.hasBiometricLogin();
    if (mounted) setState(() { biometricAvailable = available; savedBiometric = saved; });
  }

  Future<void> login() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final session = await widget.auth.login(username.text, pin.text);
      if (session == null) {
        if (mounted) setState(() { error = 'Incorrect username or PIN.'; busy = false; });
        return;
      }
      if (rememberBiometric) await widget.auth.enableBiometric(session, pin.text);
      widget.onLoggedIn(session);
    } catch (e) {
      if (mounted) setState(() { error = 'Could not sign in: $e'; busy = false; });
    }
  }

  Future<void> loginWithBiometric() async {
    if (busy) return;
    setState(() { busy = true; error = null; });
    try {
      final session = await widget.auth.loginWithBiometric();
      if (session == null) {
        if (mounted) setState(() { error = 'Biometric login was cancelled, unavailable, or needs to be enabled after a PIN login.'; busy = false; });
        return;
      }
      widget.onLoggedIn(session);
    } catch (e) {
      if (mounted) setState(() { error = 'Biometric login failed: $e'; busy = false; });
    }
  }

  Future<void> clearSavedBiometric() async {
    await widget.auth.clearBiometricLogin();
    if (mounted) setState(() { savedBiometric = false; rememberBiometric = false; });
  }

  @override
  Widget build(BuildContext context) => _AuthCard(
        title: 'Sign in to Gajurmukhi',
        subtitle: 'Use your assigned Admin, Shop, or Collector account.',
        fields: [
          TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: 12),
          TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN')),
          if (biometricAvailable) CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: rememberBiometric,
            onChanged: busy ? null : (value) => setState(() => rememberBiometric = value ?? false),
            title: const Text('Enable fingerprint / face login'),
            subtitle: const Text('The PIN is never saved in plain text.'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (savedBiometric) Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: busy ? null : clearSavedBiometric, icon: const Icon(Icons.delete_outline), label: const Text('Clear saved biometric login')),
          ),
        ],
        error: error,
        action: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(onPressed: busy ? null : login, child: Text(busy ? 'Checking…' : 'Sign in')),
            if (biometricAvailable && savedBiometric) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: busy ? null : loginWithBiometric, icon: const Icon(Icons.fingerprint), label: const Text('Use fingerprint / face login')),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CloudLoginScreen(auth: widget.auth, onLoggedIn: widget.onLoggedIn))),
              icon: const Icon(Icons.cloud_sync_outlined),
              label: const Text('Sign in to shared cloud'),
            ),
          ],
        ),
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

class BiometricSettingsScreen extends StatefulWidget {
  final LocalAuthService auth;
  final LocalSession session;
  const BiometricSettingsScreen({super.key, required this.auth, required this.session});
  @override State<BiometricSettingsScreen> createState() => _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  final pin = TextEditingController();
  bool available = false;
  bool enabled = false;
  bool busy = false;
  String? message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([widget.auth.isBiometricAvailable(), widget.auth.hasBiometricLogin()]);
    if (mounted) setState(() { available = values[0]; enabled = values[1]; });
  }

  Future<void> _enable() async {
    if (pin.text.length < 4) { setState(() => message = 'Enter your current PIN to enable biometric login.'); return; }
    setState(() { busy = true; message = null; });
    try {
      final verified = await widget.auth.login(widget.session.username, pin.text);
      if (verified == null) {
        if (mounted) setState(() { message = 'Current PIN is incorrect.'; busy = false; });
        return;
      }
      final result = await widget.auth.enableBiometric(widget.session, pin.text);
      if (mounted) setState(() { enabled = result; message = result ? 'Biometric login enabled on this device.' : 'No enrolled fingerprint or face was confirmed.'; busy = false; });
    } catch (e) {
      if (mounted) setState(() { message = 'Could not enable biometric login: $e'; busy = false; });
    }
  }

  Future<void> _disable() async {
    await widget.auth.clearBiometricLogin();
    if (mounted) setState(() { enabled = false; message = 'Saved biometric login cleared from this device.'; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Device & business settings')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: ValueListenableBuilder<String>(
            valueListenable: AppSettingsService.currencyCode,
            builder: (context, code, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Business currency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('The selected code is used for new billing, balance, payment, QR-label, receipt, and WhatsApp displays. Amounts are not converted.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: code,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: AppSettingsService.currencies.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                onChanged: widget.session.role == 'admin' ? (value) { if (value != null) AppSettingsService.setCurrency(value); } : null,
              ),
              if (widget.session.role != 'admin') const Padding(padding: EdgeInsets.only(top: 8), child: Text('Only Admin can change this business setting.', style: TextStyle(fontSize: 12))),
            ]),
          ))),
          const SizedBox(height: 12),
          Card(child: ListTile(leading: Icon(available ? Icons.verified_user : Icons.warning_amber_rounded), title: Text(available ? 'Biometrics available' : 'Biometrics unavailable'), subtitle: Text(available ? 'Fingerprint or face authentication is ready on this device.' : 'Enroll a fingerprint or face in Android settings first.'))),
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(enabled ? 'Biometric login is enabled' : 'Biometric login is disabled', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Only the username and a SHA-256 PIN verifier are stored in encrypted Android storage. Your PIN is not stored as readable text.'),
            const SizedBox(height: 16),
            if (!enabled) ...[
              TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current PIN')),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: !available || busy ? null : _enable, icon: const Icon(Icons.fingerprint), label: Text(busy ? 'Waiting for verification…' : 'Enable fingerprint / face login')),
            ] else OutlinedButton.icon(onPressed: busy ? null : _disable, icon: const Icon(Icons.delete_outline), label: const Text('Disable and clear saved login')),
            if (message != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message!)),
          ]))),
        ]),
      );

  @override
  void dispose() { pin.dispose(); super.dispose(); }
}

class MainShell extends StatefulWidget {
  final LocalSession session;
  const MainShell({super.key, required this.session});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  bool syncing = false;
  String? pendingBarcode;

  bool canAccess(int destination) => RolePermissions.canAccess(widget.session.role, destination);

  void navigate(int destination) {
    if (!canAccess(destination)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your role does not have access to this area.')));
      return;
    }
    setState(() => index = destination);
  }

  Future<void> scanFromDashboard() async {
    final barcode = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
    if (!mounted || barcode == null || barcode.trim().isEmpty) return;
    setState(() {
      pendingBarcode = barcode.trim();
      index = 1;
    });
  }

  Future<void> syncCloud(BusinessProvider provider) async {
    if (syncing) return;
    setState(() => syncing = true);
    try {
      final cloud = MobileCloudService();
      final session = await cloud.savedSession();
      if (session == null) throw StateError('Sign in to the shared cloud first.');
      final received = await AuthenticatedSyncCoordinator(db: provider.db, cloud: cloud, session: session).syncNow();
      await provider.refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloud sync complete. $received shared updates received.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloud sync could not complete: $error')));
    }
    if (mounted) setState(() => syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<BusinessProvider>();
    final screens = [
      DashboardScreen(p, onNavigate: navigate, onScanToBill: scanFromDashboard),
      BillingScreen(p, initialBarcode: pendingBarcode, onInitialBarcodeConsumed: () {
        if (mounted && pendingBarcode != null) setState(() => pendingBarcode = null);
      }),
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
      LoansScreen(p),
    ];
    const navigationTargets = [0, 5, 2, 4, 7];
    final selectedNavigationIndex = navigationTargets.indexOf(index);
    final activeScreen = canAccess(index) ? screens[index] : DashboardScreen(p, onNavigate: navigate);
    return Scaffold(
      appBar: index == 0 ? null : AppBar(
        title: Text('${AppProfile.current.name} · ${widget.session.role.toUpperCase()}'),
        actions: [
          IconButton(onPressed: syncing ? null : () => syncCloud(p), tooltip: 'Sync shared cloud', icon: syncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_sync)),
              PopupMenuButton<String>(
                onSelected: (value) { if (value == 'games') navigate(8); if (value == 'music') navigate(9); if (value == 'lucky_draw') navigate(10); if (value == 'orders') navigate(11); if (value == 'browser') navigate(12); if (value == 'loans') navigate(13); if (value == 'logout') Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => LocalAuthGate(db: p.db)), (_) => false); if (value == 'settings') Navigator.of(context).push(MaterialPageRoute(builder: (_) => BiometricSettingsScreen(auth: LocalAuthService(p.db), session: widget.session))); if (value == 'users' && widget.session.role == 'admin') Navigator.of(context).push(MaterialPageRoute(builder: (_) => UsersScreen(p.db))); },
              itemBuilder: (_) => [
              const PopupMenuItem(value: 'games', child: Text('Daily progress & rewards')),
              const PopupMenuItem(value: 'music', child: Text('YouTube Music')),
                if (widget.session.role == 'admin') const PopupMenuItem(value: 'users', child: Text('Users & Roles')),
                if (widget.session.role == 'admin') const PopupMenuItem(value: 'loans', child: Text('Loan accounts')),
              if (widget.session.role == 'admin' || widget.session.role == 'shop' || widget.session.role == 'customer') const PopupMenuItem(value: 'lucky_draw', child: Text('Monthly Lucky Draw')),
              if (widget.session.role == 'admin' || widget.session.role == 'shop' || widget.session.role == 'customer') const PopupMenuItem(value: 'orders', child: Text('Orders & Reminders')),
              if (widget.session.role == 'admin' || widget.session.role == 'shop' || widget.session.role == 'collector' || widget.session.role == 'customer') const PopupMenuItem(value: 'browser', child: Text('In-app browser')),
              const PopupMenuItem(value: 'settings', child: Text('Device & business settings')),
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
