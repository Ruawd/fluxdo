import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/discourse_site.dart';
import 'active_site_service.dart';
import 'auth_session.dart';
import 'background/background_notification_service.dart';
import 'browser_trust_coordinator.dart';
import 'cf_challenge_service.dart';
import 'cf_clearance_refresh_service.dart';
import 'discourse/discourse_service.dart';
import 'message_bus_service.dart';
import 'network/cookie/csrf_token_service.dart';
import 'network/cookie/webview_cookie_priming.dart';
import 'preloaded_data_service.dart';
import 'webview_session_cookie_refresh_service.dart';

enum SiteSwitchResult { switched, unchanged, verificationInProgress, failed }

/// 在不重启 App 的情况下切换 Discourse 社区。
///
/// 顺序很重要：先停旧站点后台任务并推进请求 generation，再卸载旧根容器，
/// 最后才暂存新站点。这样 stage 到 publish 的窗口内不会有旧 Widget 读取新配置。
class SiteSwitchCoordinator {
  SiteSwitchCoordinator._();
  static final SiteSwitchCoordinator instance = SiteSwitchCoordinator._();

  static const Duration _backgroundCleanupTimeout = Duration(seconds: 3);
  static const Duration _oldSiteDrainTimeout = Duration(seconds: 4);
  static const Duration _webViewStopTimeout = Duration(seconds: 5);

  Future<SiteSwitchResult>? _activeSwitch;
  bool get isSwitching => _activeSwitch != null;

  Future<SiteSwitchResult> switchTo(DiscourseSite target) {
    final running = _activeSwitch;
    if (running != null) return running;

    late final Future<SiteSwitchResult> operation;
    operation = _switchTo(target).whenComplete(() {
      if (identical(_activeSwitch, operation)) _activeSwitch = null;
    });
    _activeSwitch = operation;
    return operation;
  }

  Future<SiteSwitchResult> _switchTo(DiscourseSite target) async {
    final activeSite = ActiveSiteService.instance;
    final previous = activeSite.current;
    if (previous.id == target.id) return SiteSwitchResult.unchanged;

    final oldChallenge = CfChallengeService();
    if (oldChallenge.isVerifying) {
      return SiteSwitchResult.verificationInProgress;
    }

    // 在 stage 前保存旧实例；stage 后同名 factory 会解析为目标站点实例。
    final oldBrowserTrust = BrowserTrustCoordinator.instance;
    final oldClearanceRefresh = CfClearanceRefreshService();
    final oldSessionRefresh = WebViewSessionCookieRefreshService.instance;
    var transitionStarted = false;

    try {
      MessageBusService().stopAll();
      AuthSession().advance();

      // 三项资源彼此独立且实例都已绑定旧站点；并行收尾可把异常情况下的
      // 最长等待限制在 5 秒，而不是把多个平台插件超时串行累加。
      await Future.wait([
        _bestEffortCleanup(
          'background_notification',
          BackgroundNotificationService().disable,
          _backgroundCleanupTimeout,
        ),
        _bestEffortCleanup(
          'browser_trust_drain',
          oldBrowserTrust.suspendForSiteSwitch,
          _oldSiteDrainTimeout,
        ),
        _bestEffortCleanup(
          'cf_clearance_webview_stop',
          oldClearanceRefresh.stop,
          _webViewStopTimeout,
        ),
      ]);
      oldSessionRefresh.resetSessionState(reason: 'site_switch_out');
      WebViewCookiePriming.instance.invalidate();

      // 先让旧 Navigator 与 ProviderScope 真正卸载一帧，再改变 current。
      // 否则旧 provider 的延迟回调可能把 Linux.do 数据写进 IDC Flare key。
      activeSite.beginTransition();
      transitionStarted = true;
      await WidgetsBinding.instance.endOfFrame;

      await activeSite.stage(target);

      // 以下 factory 均按 target.id 返回独立实例。
      MessageBusService().resetForSiteSwitch();
      await CsrfTokenService().init();
      PreloadedDataService().reset();
      await DiscourseService().activateForSiteSwitch();
      CfChallengeService()
        ..resetCooldown()
        ..resetSessionCompatibilityDecision();
      WebViewSessionCookieRefreshService.instance.resetSessionState(
        reason: 'site_switch_in',
      );

      // 最后才触发整棵 ProviderScope 重建。
      activeSite.publish();
      activeSite.finishTransition();
      transitionStarted = false;
      BrowserTrustCoordinator.instance.prepareStartup(reason: 'site_switch');
      debugPrint(
        '[SiteSwitch] ${previous.displayName} -> ${target.displayName}',
      );
      return SiteSwitchResult.switched;
    } catch (e, stackTrace) {
      debugPrint('[SiteSwitch] 切换失败: $e\n$stackTrace');
      try {
        await activeSite.stage(previous);
        MessageBusService().resetForSiteSwitch();
        WebViewCookiePriming.instance.invalidate();
        await CsrfTokenService().init();
        PreloadedDataService().reset();
        await DiscourseService().activateForSiteSwitch();
        CfChallengeService()
          ..resetCooldown()
          ..resetSessionCompatibilityDecision();
        WebViewSessionCookieRefreshService.instance.resetSessionState(
          reason: 'site_switch_rollback',
        );
        // 如果异常发生在 publish 之后，必须把根 ProviderScope 也切回旧站点。
        activeSite.publish();
        activeSite.finishTransition();
        transitionStarted = false;
        BrowserTrustCoordinator.instance.prepareStartup(
          reason: 'site_switch_rollback',
        );
      } catch (rollbackError) {
        debugPrint('[SiteSwitch] 回滚失败: $rollbackError');
      }
      return SiteSwitchResult.failed;
    } finally {
      if (transitionStarted) {
        activeSite.finishTransition();
      }
    }
  }

  /// 旧站点收尾属于 best-effort：所有服务实例都已绑定旧域名，
  /// 即使平台插件不回调，超时后继续也不会把数据写进新社区。
  /// 不能让 Workmanager/WebView 的一次异常永久锁住整个 App。
  Future<void> _bestEffortCleanup(
    String phase,
    Future<void> Function() cleanup,
    Duration timeout,
  ) async {
    try {
      await cleanup().timeout(timeout);
    } on TimeoutException {
      debugPrint(
        '[SiteSwitch] 旧站点收尾超时，继续切换: '
        'phase=$phase timeout=${timeout.inSeconds}s',
      );
    } catch (e, stackTrace) {
      debugPrint('[SiteSwitch] 旧站点收尾失败，继续切换: phase=$phase error=$e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
