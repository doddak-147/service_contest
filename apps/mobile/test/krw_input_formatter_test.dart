import 'package:financial_shock_preview/shared/input/krw_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatKrwInput', () {
    test('원화 정수에 천 단위 쉼표를 표시한다', () {
      expect(formatKrwInput('3000000'), '3,000,000');
      expect(formatKrwInput('0'), '0');
      expect(formatKrwInput('0001200'), '1,200');
    });

    test('음수 부호는 유지한다', () {
      expect(formatKrwInput('-3000000'), '-3,000,000');
    });
  });

  group('KrwInputFormatter', () {
    const formatter = KrwInputFormatter();

    test('사용자가 입력한 숫자를 즉시 천 단위로 구분한다', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '3000000',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );

      expect(result.text, '3,000,000');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('숫자가 아닌 입력은 이전 값을 유지한다', () {
      const oldValue = TextEditingValue(
        text: '3,000',
        selection: TextSelection.collapsed(offset: 5),
      );
      final result = formatter.formatEditUpdate(
        oldValue,
        const TextEditingValue(text: '3,000원'),
      );

      expect(result, oldValue);
    });
  });
}
