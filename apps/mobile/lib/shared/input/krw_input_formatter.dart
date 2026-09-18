import 'package:flutter/services.dart';

String formatKrwInput(String value) {
  final normalized = value.replaceAll(',', '').trim();
  if (normalized.isEmpty || normalized == '-') {
    return normalized;
  }

  final isNegative = normalized.startsWith('-');
  var digits = isNegative ? normalized.substring(1) : normalized;
  if (!RegExp(r'^\d+$').hasMatch(digits)) {
    return value;
  }

  digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = (end - 3).clamp(0, digits.length).toInt();
    groups.add(digits.substring(start, end));
  }
  final grouped = groups.reversed.join(',');
  return isNegative ? '-$grouped' : grouped;
}

class KrwInputFormatter extends TextInputFormatter {
  const KrwInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = newValue.text.replaceAll(',', '');
    if (!RegExp(r'^-?\d*$').hasMatch(normalized)) {
      return oldValue;
    }

    final formatted = formatKrwInput(normalized);
    final selectionOffset = newValue.selection.extentOffset
        .clamp(0, newValue.text.length)
        .toInt();
    final digitsBeforeCursor = RegExp(
      r'\d',
    ).allMatches(newValue.text.substring(0, selectionOffset)).length;
    final cursorOffset = _cursorOffsetForDigitCount(
      formatted,
      digitsBeforeCursor,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }
}

int _cursorOffsetForDigitCount(String text, int digitCount) {
  if (text.isEmpty) {
    return 0;
  }
  if (digitCount == 0) {
    return text.startsWith('-') ? 1 : 0;
  }

  var seenDigits = 0;
  for (var index = 0; index < text.length; index++) {
    if (RegExp(r'\d').hasMatch(text[index])) {
      seenDigits++;
      if (seenDigits == digitCount) {
        return index + 1;
      }
    }
  }
  return text.length;
}
