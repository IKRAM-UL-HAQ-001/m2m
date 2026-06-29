import 'package:flutter_test/flutter_test.dart';
import 'package:m2m/services/api_service.dart';

void main() {
  const expected = '+923435149587';
  final inputs = <String>[
    '00923435149587',
    '+923435149587',
    '03435149587',
    '923435149587',
    '3435149587',
    '+92 343-514 9587',
    '(0343) 5149587',
    '0092 343 5149587',
  ];
  for (final input in inputs) {
    test('normalizes "$input" -> $expected', () {
      expect(ApiService.normalizeContactPhone(input), expected);
    });
  }
  test('reusable for US (+1)', () {
    expect(
      ApiService.normalizeContactPhone('212-555-0123', defaultCountryCode: '+1'),
      '+12125550123',
    );
  });
  test('empty stays empty', () {
    expect(ApiService.normalizeContactPhone(''), '');
    expect(ApiService.normalizeContactPhone(null), '');
  });
}
