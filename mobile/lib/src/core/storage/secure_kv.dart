import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class SecureKv {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

final secureKvProvider = Provider<SecureKv>((ref) {
  return _FlutterSecureKv(const FlutterSecureStorage());
});

class _FlutterSecureKv implements SecureKv {
  _FlutterSecureKv(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

