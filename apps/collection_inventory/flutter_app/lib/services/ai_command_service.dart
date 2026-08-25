import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiCommandResult {
  final String message;
  final bool changed;
  final bool requiresConfirmation;
  final String? confirmationToken;

  const AiCommandResult({required this.message, this.changed = false, this.requiresConfirmation = false, this.confirmationToken});
}

class AppSettingsService {
  static const themeKey = 'gajurmukhi_theme_mode';
  static const defaultPaymentKey = 'gajurmukhi_default_payment_method';
  static const lowStockKey = 'gajurmukhi_low_stock_threshold';
  static const currencyKey = 'gajurmukhi_currency_code';
  static const currencies = <String, String>{
    'NPR': 'NPR · Nepalese Rupee',
    'INR': 'INR · Indian Rupee',
    'USD': 'USD · US Dollar',
    'EUR': 'EUR · Euro',
    'GBP': 'GBP · British Pound',
  };
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);
  static final ValueNotifier<String> currencyCode = ValueNotifier('NPR');

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode.value = _themeFrom(prefs.getString(themeKey));
    currencyCode.value = _currencyFrom(prefs.getString(currencyKey));
  }

  static ThemeMode _themeFrom(String? value) => switch (value) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };

  static String _currencyFrom(String? value) {
    final code = value?.trim().toUpperCase() ?? 'NPR';
    return currencies.containsKey(code) ? code : 'NPR';
  }

  static String money(num value) => '${currencyCode.value} ${value.toStringAsFixed(2)}';

  static Future<void> setTheme(String value) async {
    final normalized = value.trim().toLowerCase();
    final mode = _themeFrom(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeKey, normalized == 'dark' || normalized == 'system' ? normalized : 'light');
    themeMode.value = mode;
  }

  static Future<void> setCurrency(String value) async {
    final code = _currencyFrom(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(currencyKey, code);
    currencyCode.value = code;
  }

  static Future<String?> read(String key) async => (await SharedPreferences.getInstance()).getString(key);
  static Future<void> write(String key, String value) async => (await SharedPreferences.getInstance()).setString(key, value);
}

class AiCommandService {
  static const supportedCommands = '''Try commands such as:
• set theme to dark / light / system
• set default payment to cash / qr / bank
• set low stock alert to 10
• set currency to NPR / INR / USD / EUR / GBP
• show current settings
• help''';

  Future<AiCommandResult> execute({required String command, required String role, bool confirmed = false}) async {
    final text = command.trim();
    final lower = text.toLowerCase();
    if (text.isEmpty || lower == 'help' || lower == 'commands') return const AiCommandResult(message: supportedCommands);

    final theme = RegExp(r'(?:set\s+)?theme\s+(?:to\s+)?(dark|light|system)').firstMatch(lower)?.group(1);
    if (theme != null) {
      await AppSettingsService.setTheme(theme);
      await _audit(role, text, 'theme=$theme');
      return AiCommandResult(message: 'Theme changed to $theme. This change is saved on this phone.', changed: true);
    }

    if (lower.contains('show current settings') || lower == 'settings') {
      final prefs = await SharedPreferences.getInstance();
      final themeValue = prefs.getString(AppSettingsService.themeKey) ?? 'light';
      final payment = prefs.getString(AppSettingsService.defaultPaymentKey) ?? 'cash';
      final lowStock = prefs.getString(AppSettingsService.lowStockKey) ?? '5';
      final currency = prefs.getString(AppSettingsService.currencyKey) ?? 'NPR';
      return AiCommandResult(message: 'Current settings on this phone:\nTheme: $themeValue\nDefault payment: $payment\nCurrency: $currency\nLow-stock alert: $lowStock units.');
    }

    final payment = RegExp(r'(?:set\s+)?(?:default\s+)?payment\s+(?:to\s+)?(cash|qr|bank)').firstMatch(lower)?.group(1);
    if (payment != null) {
      if (role != 'admin') return const AiCommandResult(message: 'Only Admin can change the default payment method.');
      if (!confirmed) return AiCommandResult(message: 'This changes the default payment method to ${payment.toUpperCase()} for this phone. Press Confirm to apply it.', requiresConfirmation: true, confirmationToken: 'payment:$payment');
      await AppSettingsService.write(AppSettingsService.defaultPaymentKey, payment);
      await _audit(role, text, 'default_payment=$payment');
      return AiCommandResult(message: 'Default payment method changed to ${payment.toUpperCase()}.', changed: true);
    }

    final currency = RegExp(r'(?:set\s+)?currency\s+(?:to\s+)?(npr|inr|usd|eur|gbp)').firstMatch(lower)?.group(1);
    if (currency != null) {
      if (role != 'admin') return const AiCommandResult(message: 'Only Admin can change the business currency.');
      final code = currency.toUpperCase();
      if (!confirmed) return AiCommandResult(message: 'This changes the displayed currency to $code for new billing, payment, balance, receipt, and message displays on this phone. Historic amounts are not converted. Press Confirm to apply it.', requiresConfirmation: true, confirmationToken: 'currency:$code');
      await AppSettingsService.setCurrency(code);
      await _audit(role, text, 'currency=$code');
      return AiCommandResult(message: 'Business currency changed to $code. Existing amounts were not converted.', changed: true);
    }

    final lowStock = RegExp(r'(?:set\s+)?low\s*stock\s+(?:alert\s+)?(?:to\s+)?(\d+(?:\.\d+)?)').firstMatch(lower)?.group(1);
    if (lowStock != null) {
      if (role != 'admin') return const AiCommandResult(message: 'Only Admin can change the low-stock alert threshold.');
      if (!confirmed) return AiCommandResult(message: 'This changes the low-stock alert threshold to $lowStock units. Press Confirm to apply it.', requiresConfirmation: true, confirmationToken: 'low_stock:$lowStock');
      await AppSettingsService.write(AppSettingsService.lowStockKey, lowStock);
      await _audit(role, text, 'low_stock=$lowStock');
      return AiCommandResult(message: 'Low-stock alert threshold changed to $lowStock units.', changed: true);
    }

    return const AiCommandResult(message: 'I can answer business questions through the AI assistant, but I only change approved settings commands.\n\n$supportedCommands');
  }

  Future<void> _audit(String role, String command, String change) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList('gajurmukhi_ai_command_audit') ?? <String>[];
    entries.add('${DateTime.now().toIso8601String()}|$role|$change|$command');
    await prefs.setStringList('gajurmukhi_ai_command_audit', entries.length > 50 ? entries.sublist(entries.length - 50) : entries);
  }
}
