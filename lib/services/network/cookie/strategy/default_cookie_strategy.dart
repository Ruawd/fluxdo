import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../raw_cookie_writer.dart';
import 'platform_cookie_strategy.dart';

/// 默认 cookie 策略（Windows 等）
class DefaultCookieStrategy implements PlatformCookieStrategy {
  @override
  Future<List<Cookie>> readCookiesFromWebView(
    CookieManager cookieManager,
    String url,
  ) async {
    return cookieManager.getCookies(url: WebUri(url));
  }

  @override
  Future<void> clearWebViewCookies(
    CookieManager cookieManager,
    Set<String> knownHosts,
  ) async {
    await cookieManager.deleteAllCookies();
  }

  @override
  Future<void> clearWebViewCookiesForSite(
    CookieManager cookieManager,
    Set<String> knownHosts,
    String baseUrl,
  ) async {
    final baseHost = Uri.parse(baseUrl).host.toLowerCase();
    bool related(String? rawDomain) {
      final domain = rawDomain?.trim().toLowerCase().replaceFirst(
        RegExp(r'^\.'),
        '',
      );
      if (domain == null || domain.isEmpty) return false;
      return domain == baseHost || domain.endsWith('.$baseHost');
    }

    // getAllCookies 能覆盖只存在于 WebView、尚未同步进 jar 的子域 cookie。
    try {
      final all = await cookieManager.getAllCookies();
      for (final cookie in all.where((cookie) => related(cookie.domain))) {
        final domain = cookie.domain?.replaceFirst(RegExp(r'^\.'), '').trim();
        final host = domain == null || domain.isEmpty ? baseHost : domain;
        await cookieManager.deleteCookie(
          url: WebUri('https://$host'),
          name: cookie.name,
          domain: cookie.domain,
          path: cookie.path ?? '/',
        );
      }
    } catch (e) {
      debugPrint('[CookieStrategy] getAllCookies 精确清理失败，继续逐 host: $e');
    }

    // host-only cookie 在部分平台的 getAllCookies 结果不带 domain，逐 host 兜底。
    for (final host in {...knownHosts, baseHost}) {
      try {
        final url = WebUri('https://$host');
        final cookies = await cookieManager.getCookies(url: url);
        for (final cookie in cookies) {
          await cookieManager.deleteCookie(
            url: url,
            name: cookie.name,
            domain: cookie.domain,
            path: cookie.path ?? '/',
          );
        }
      } catch (e) {
        debugPrint('[CookieStrategy] 逐 host 清理失败 host=$host: $e');
      }
    }
  }

  @override
  Future<int> writeRawCookiesToWebView(
    List<(String url, String rawHeader)> entries,
  ) async {
    final writer = RawCookieWriter.instance;
    if (!writer.isSupported) return 0;

    var written = 0;
    for (final (url, raw) in entries) {
      try {
        if (await writer.setRawCookie(url, raw)) written++;
      } catch (e) {
        debugPrint('[CookieStrategy] 写入 WebView 失败: $e');
      }
    }
    return written;
  }
}
