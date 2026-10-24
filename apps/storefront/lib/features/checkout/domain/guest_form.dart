import 'package:core/core.dart';

/// Validation for the guest checkout form. Returns an error key or null.
abstract final class GuestValidation {
  /// Egyptian mobile numbers: 11 digits starting with 010, 011, 012 or 015.
  static final _phone = RegExp(r'^01[0125]\d{8}$');

  static String? name(String v) => v.trim().length < 2 ? 'name' : null;

  static String? phone(String v) =>
      _phone.hasMatch(_normalizeDigits(v.trim())) ? null : 'phone';

  static String? address(String v, Fulfillment f) =>
      f == Fulfillment.delivery && v.trim().length < 5 ? 'address' : null;

  /// Accepts Arabic-Indic digits as typed on Arabic keyboards.
  static String normalizePhone(String v) => _normalizeDigits(v.trim());

  static String _normalizeDigits(String v) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in v.split('')) {
      final i = arabic.indexOf(ch);
      b.write(i >= 0 ? '$i' : ch);
    }
    return b.toString().replaceAll(RegExp(r'[\s-]'), '');
  }
}
