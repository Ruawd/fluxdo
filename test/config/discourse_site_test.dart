import 'package:flutter_test/flutter_test.dart';
import 'package:fluxdo/config/discourse_site.dart';
import 'package:fluxdo/services/active_site_service.dart';
import 'package:fluxdo/services/network/cookie/cookie_jar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DiscourseSiteRegistry', () {
    test('只识别 IDC Flare 主域和子域', () {
      expect(
        DiscourseSiteRegistry.byHost('www.idcflare.com')?.id,
        DiscourseSiteRegistry.idcFlareId,
      );
      expect(DiscourseSiteRegistry.byHost('linux.do'), isNull);
      expect(DiscourseSiteRegistry.byHost('connect.linux.do'), isNull);
      expect(DiscourseSiteRegistry.byHost('notlinux.do'), isNull);
      expect(DiscourseSiteRegistry.byHost('idcflare.com.example.com'), isNull);
      expect(DiscourseSiteRegistry.all, [DiscourseSiteRegistry.idcFlare]);
      expect(DiscourseSiteRegistry.defaultSite, DiscourseSiteRegistry.idcFlare);
    });

    test('登录入口和功能开关符合 IDC Flare 能力', () {
      expect(
        DiscourseSiteRegistry.idcFlare.preferredLoginUrl,
        'https://idcflare.com/auth/oauth2_basic',
      );
      expect(DiscourseSiteRegistry.idcFlare.supportsChat, isFalse);
      expect(
        DiscourseSiteRegistry.idcFlare.supportsNativePasswordLogin,
        isFalse,
      );
    });

    test('IDC Flare 使用独立存储和账号命名空间', () {
      expect(
        DiscourseSiteRegistry.idcFlare.scopedStorageKey('current_user_cache'),
        'current_user_cache_idcflare',
      );
      expect(
        DiscourseSiteRegistry.idcFlare.scopedAccountId('alice'),
        'fluxdo_scoped_account_id_v1__idcflare__YWxpY2U',
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

  test('ActiveSiteService 忽略历史站点并固定为 IDC Flare', () async {
    SharedPreferences.setMockInitialValues({
      ActiveSiteService.preferenceKey: 'linuxdo',
    });
    final prefs = await SharedPreferences.getInstance();
    final service = ActiveSiteService.instance;
    await service.initialize(prefs);

    expect(service.current.id, DiscourseSiteRegistry.idcFlareId);
    expect(
      prefs.getString(ActiveSiteService.preferenceKey),
      DiscourseSiteRegistry.idcFlareId,
    );
  });
}
