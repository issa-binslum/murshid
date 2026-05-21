/// Formats a number with comma thousands-separators.
/// Drops decimal part when it is exactly .00, otherwise shows 2 dp.
/// e.g.  1500000  →  "1,500,000"
///       1500000.5 →  "1,500,000.50"
String fmtNumber(double v) {
  final fixed = v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = _addCommas(parts[0]);
  return parts[1] == '00' ? intPart : '$intPart.${parts[1]}';
}

/// Same as [fmtNumber] but prefixes "TZS ".
String fmtMoney(double v) => ' ${fmtNumber(v)}';

String _addCommas(String s) {
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
