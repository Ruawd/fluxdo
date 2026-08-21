import '../config/discourse_site.dart';
import 'active_site_service.dart';
import 'storage/resilient_secure_storage.dart';

/// 登录凭证安全存储服务（单例）
class CredentialStoreService {
  CredentialStoreService._(DiscourseSite site)
    : _keyUsername = site.scopedStorageKey('login_credential_username'),
      _keyPassword = site.scopedStorageKey('login_credential_password');
  static final Map<String, CredentialStoreService> _instances = {};
  factory CredentialStoreService() {
    final site = ActiveSiteService.instance.current;
    return _instances.putIfAbsent(
      site.id,
      () => CredentialStoreService._(site),
    );
  }

  final String _keyUsername;
  final String _keyPassword;

  final _storage = ResilientSecureStorage();

  /// 保存凭证
  Future<void> save(String username, String password) async {
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyPassword, value: password);
  }

  /// 读取凭证
  Future<({String? username, String? password})> load() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);
    return (username: username, password: password);
  }

  /// 清除凭证
  Future<void> clear() async {
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyPassword);
  }

  /// 是否已保存凭证
  Future<bool> hasCredentials() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);
    return username != null &&
        password != null &&
        username.isNotEmpty &&
        password.isNotEmpty;
  }
}
