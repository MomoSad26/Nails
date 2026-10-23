import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  static Future<bool> openMessage({String? phone, required String message}) async {
    final encoded = Uri.encodeComponent(message);
    final normalizedPhone = phone == null ? '' : digitsOnly(phone);
    final candidates = <Uri>[];
    if (normalizedPhone.isNotEmpty) {
      candidates.add(Uri.parse('whatsapp://send?phone=$normalizedPhone&text=$encoded'));
      candidates.add(Uri.parse('https://wa.me/$normalizedPhone?text=$encoded'));
    } else {
      candidates.add(Uri.parse('whatsapp://send?text=$encoded'));
      candidates.add(Uri.parse('https://wa.me/?text=$encoded'));
    }
    for (final uri in candidates) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
      } catch (_) {
        // Try the web fallback if the custom WhatsApp scheme is unavailable.
      }
    }
    return false;
  }

  static Future<bool> callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
