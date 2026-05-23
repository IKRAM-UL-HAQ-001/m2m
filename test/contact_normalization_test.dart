import 'package:flutter_test/flutter_test.dart';
import 'package:m2m/services/api_service.dart';

void main() {
  group('ApiService.normalizeContactPhone', () {
    test('normalizes Pakistan mobile formats to E.164', () {
      expect(
        ApiService.normalizeContactPhone('+923001234567'),
        '+923001234567',
      );
      expect(ApiService.normalizeContactPhone('03001234567'), '+923001234567');
      expect(ApiService.normalizeContactPhone('3001234567'), '+923001234567');
      expect(ApiService.normalizeContactPhone('923001234567'), '+923001234567');
    });

    test('strips separators and brackets', () {
      expect(
        ApiService.normalizeContactPhone('+92 (300) 123-4567'),
        '+923001234567',
      );
      expect(
        ApiService.normalizeContactPhone('0300 123 4567'),
        '+923001234567',
      );
    });
  });
}
