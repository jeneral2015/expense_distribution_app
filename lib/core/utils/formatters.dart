extension NumberFormatting on num? {
  String toAppString({int decimals = 2}) {
    if (this == null) return '0';
    final d = this!.toDouble();
    if (d == d.toInt()) return d.toInt().toString();
    return d.toStringAsFixed(decimals);
  }
}

class Formatters {
  static double toDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) {
      final p = double.tryParse(v.trim().replaceAll(',', '.'));
      if (p != null) return p;
    }
    return fallback;
  }

  static int toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final p = int.tryParse(v.trim());
      if (p != null) return p;
    }
    return fallback;
  }

  static String toAppString(dynamic value, {int decimals = 2}) {
    if (value == null) return '0';
    if (value is num) return value.toAppString(decimals: decimals);
    if (value is String) {
      final d = double.tryParse(value.trim().replaceAll(',', '.'));
      if (d != null) return d.toAppString(decimals: decimals);
      return value;
    }
    return value.toString();
  }

  static String formatNum(num? number, {int decimals = 2}) {
    return number.toAppString(decimals: decimals);
  }
}
