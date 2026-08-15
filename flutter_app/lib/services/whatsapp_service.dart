import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
class WhatsAppService {
  static Uri messageUri(String phone, String message) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return Uri.parse('https://wa.me/$digits?text=${Uri.encodeComponent(message)}');
  }

  Future<void> shareInvoice(File pdf, String message) =>
      Share.shareXFiles([XFile(pdf.path)], text: message);

  Future<void> openMessage(String phone, String message) async {
    await launchUrl(messageUri(phone, message), mode: LaunchMode.externalApplication);
  }
}
