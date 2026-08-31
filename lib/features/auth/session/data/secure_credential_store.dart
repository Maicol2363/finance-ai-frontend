import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureCredentialStoreProvider = Provider<SecureCredentialStore>((ref) {
  return const FlutterSecureCredentialStore(FlutterSecureStorage());
});

abstract interface class SecureCredentialStore {
  Future<String?> read();

  Future<void> replace(String renewableCredential);

  Future<void> delete();
}

class FlutterSecureCredentialStore implements SecureCredentialStore {
  const FlutterSecureCredentialStore(
    this._storage, {
    String credentialKey = 'finance_ai.renewable_session',
  }) : _renewableKey = credentialKey;

  final FlutterSecureStorage _storage;
  final String _renewableKey;

  @override
  Future<String?> read() => _storage.read(key: _renewableKey);

  @override
  Future<void> replace(String renewableCredential) {
    return _storage.write(key: _renewableKey, value: renewableCredential);
  }

  @override
  Future<void> delete() => _storage.delete(key: _renewableKey);
}
