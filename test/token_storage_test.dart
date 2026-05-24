import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:m2m/services/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  setUp(() {
    TokenStorage.resetForTesting();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('reads tokens from secure storage into memory cache', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'secure-access',
      'refresh_token': 'secure-refresh',
    });

    await TokenStorage.init();

    expect(TokenStorage.accessTokenSync, 'secure-access');
    expect(TokenStorage.refreshTokenSync, 'secure-refresh');
    expect(await TokenStorage.getAccessToken(), 'secure-access');
    expect(await TokenStorage.getRefreshToken(), 'secure-refresh');
  });

  test('migrates legacy SharedPreferences tokens to secure storage', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'legacy-access',
      'refresh_token': 'legacy-refresh',
    });

    await TokenStorage.init();

    expect(TokenStorage.accessTokenSync, 'legacy-access');
    expect(TokenStorage.refreshTokenSync, 'legacy-refresh');
    expect(await secureStorage.read(key: 'access_token'), 'legacy-access');
    expect(await secureStorage.read(key: 'refresh_token'), 'legacy-refresh');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), isNull);
    expect(prefs.getString('refresh_token'), isNull);
  });

  test(
    'saveTokens updates secure storage, memory, and clears legacy prefs',
    () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'legacy-access',
        'refresh_token': 'legacy-refresh',
      });

      await TokenStorage.saveTokens(
        access: 'new-access',
        refresh: 'new-refresh',
      );

      expect(TokenStorage.accessTokenSync, 'new-access');
      expect(TokenStorage.refreshTokenSync, 'new-refresh');
      expect(await secureStorage.read(key: 'access_token'), 'new-access');
      expect(await secureStorage.read(key: 'refresh_token'), 'new-refresh');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
    },
  );

  test(
    'clearAll removes secure tokens and legacy SharedPreferences tokens',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'secure-access',
        'refresh_token': 'secure-refresh',
      });
      SharedPreferences.setMockInitialValues({
        'access_token': 'legacy-access',
        'refresh_token': 'legacy-refresh',
        'isLoggedIn': true,
      });

      await TokenStorage.init();
      await TokenStorage.clearAll();

      expect(TokenStorage.accessTokenSync, isNull);
      expect(TokenStorage.refreshTokenSync, isNull);
      expect(await secureStorage.read(key: 'access_token'), isNull);
      expect(await secureStorage.read(key: 'refresh_token'), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
      expect(prefs.getBool('isLoggedIn'), isNull);
    },
  );
}
