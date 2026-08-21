import 'package:flutter_test/flutter_test.dart';
import 'package:fluxdo/config/discourse_site.dart';
import 'package:fluxdo/services/active_site_service.dart';
import 'package:fluxdo/services/network/cookie/cookie_jar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DiscourseSiteRegistry', () {
    test('按主域和子域识别社区，但不接受相似后缀域名', () {
      expect(
        DiscourseSiteRegistry.byHost('linux.do')?.id,
        DiscourseSiteRegistry.linuxDoId,
      );
      expect(
        DiscourseSiteRegistry.byHost('connect.linux.do')?.id,
        DiscourseSiteRegistry.linuxDoId,
      );
      expect(
        DiscourseSiteRegistry.byHost('www.idcflare.com')?.id,
        DiscourseSiteRegistry.idcFlareId,
      );
      expect(DiscourseSiteRegistry.byHost('notlinux.do'), isNull);
      expect(DiscourseSiteRegistry.byHost('idcflare.com.example.com'), isNull);
    });

    test('登录入口和功能开关符合两个站点的能力', () {
      expect(
        DiscourseSiteRegistry.linuxDo.preferredLoginUrl,
        'https://linux.do/login',
      );
      expect(
        DiscourseSiteRegistry.idcFlare.preferredLoginUrl,
        'https://idcflare.com/auth/oauth2_basic',
      );
      expect(DiscourseSiteRegistry.linuxDo.supportsChat, isTrue);
      expect(DiscourseSiteRegistry.idcFlare.supportsChat, isFalse);
      expect(
        DiscourseSiteRegistry.idcFlare.supportsNativePasswordLogin,
        isFalse,
      );
    });

    test('Linux.do 沿用旧存储键，IDC Flare 使用独立命名空间', () {
      expect(
        DiscourseSiteRegistry.linuxDo.scopedStorageKey('current_user_cache'),
        'current_user_cache',
      );
      expect(
        DiscourseSiteRegistry.idcFlare.scopedStorageKey('current_user_cache'),
        'current_user_cache_idcflare',
      );
      expect(DiscourseSiteRegistry.linuxDo.scopedAccountId('alice'), 'alice');
      expect(
        DiscourseSiteRegistry.idcFlare.scopedAccountId('alice'),
        'fluxdo_scoped_account_id_v1__idcflare__YWxpY2U',
      );
      expect(
        DiscourseSiteRegistry.idcFlare.scopedAccountId('alice'),
        isNot(DiscourseSiteRegistry.linuxDo.scopedAccountId('alice')),
      );
    });

    test('Cookie 域匹配可以显式绑定站点，不受当前社区切换影响', () {
      expect(CookieJarService.matchesSiteHost('.linux.do', 'linux.do'), isTrue);
      expect(
        CookieJarService.matchesSiteHost('connect.linux.do', 'linux.do'),
        isTrue,
      );
      expect(
        CookieJarService.matchesSiteHost('linux.do', 'idcflare.com'),
        isFalse,
      );
    });
  });

  test('ActiveSiteService 启动恢复选择，并在 publish 时才通知 UI', () async {
    SharedPreferences.setMockInitialValues({
      ActiveSiteService.preferenceKey: DiscourseSiteRegistry.idcFlareId,
    });
    final prefs = await SharedPreferences.getInstance();
    final service = ActiveSiteService.instance;
    await service.initialize(prefs);

    expect(service.current.id, DiscourseSiteRegistry.idcFlareId);
    expect(
      service.activeSiteNotifier.value.id,
      DiscourseSiteRegistry.idcFlareId,
    );

    await service.stage(DiscourseSiteRegistry.linuxDo);
    expect(service.current.id, DiscourseSiteRegistry.linuxDoId);
    expect(
      service.activeSiteNotifier.value.id,
      DiscourseSiteRegistry.idcFlareId,
    );

    service.publish();
    expect(
      service.activeSiteNotifier.value.id,
      DiscourseSiteRegistry.linuxDoId,
    );
    expect(
      prefs.getString(ActiveSiteService.preferenceKey),
      DiscourseSiteRegistry.linuxDoId,
    );
  });
}
