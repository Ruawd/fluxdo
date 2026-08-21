import 'dart:convert';

import 'site_customization.dart';
import 'sites/idcflare.dart';
import 'sites/linuxdo.dart';

/// 一个可切换的 Discourse 社区。
class DiscourseSite {
  const DiscourseSite({
    required this.id,
    required this.displayName,
    required this.shortName,
    required this.baseUrl,
    required this.description,
    required this.customization,
    this.supportsNativePasswordLogin = true,
    this.supportsBrowserAuthorizationLogin = true,
    this.supportsQrLogin = true,
    this.supportsChat = true,
    this.supportsLinuxDoEcosystem = false,
    this.supportsConnectStats = false,
    this.supportsSeeking = false,
    this.supportsLdcRewards = false,
    this.preferredLoginPath = '/login',
    this.challengePath = '/challenge',
    this.skipCsrfForHomeRequest = true,
  });

  /// 稳定存储标识；发布后不能修改。
  final String id;
  final String displayName;
  final String shortName;
  final String baseUrl;
  final String description;
  final SiteCustomization customization;

  final bool supportsNativePasswordLogin;
  final bool supportsBrowserAuthorizationLogin;
  final bool supportsQrLogin;
  final bool supportsChat;
  final bool supportsLinuxDoEcosystem;
  final bool supportsConnectStats;
  final bool supportsSeeking;
  final bool supportsLdcRewards;

  /// 首选网页登录入口。IDC Flare 直接进入 Linux.do OAuth，避免先落到
  /// 只有一个按钮的 Discourse 登录中间页。
  final String preferredLoginPath;

  /// Cloudflare 人工验证入口。没有专用 challenge 路由的站点使用首页。
  final String challengePath;
  final bool skipCsrfForHomeRequest;

  Uri get uri => Uri.parse(baseUrl);
  String get host => uri.host.toLowerCase();
  String get preferredLoginUrl => resolve(preferredLoginPath);
  String get challengeUrl => resolve(challengePath);

  String resolve(String path) {
    final parsed = Uri.tryParse(path);
    if (parsed != null && parsed.hasScheme) return parsed.toString();
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$normalized';
  }

  bool matchesHost(String candidate) {
    final normalized = candidate.toLowerCase().trim();
    return normalized == host || normalized.endsWith('.$host');
  }

  /// Linux.do 沿用历史 key，确保升级后不丢登录态和缓存；新增站点加后缀隔离。
  String scopedStorageKey(String legacyKey) {
    return id == DiscourseSiteRegistry.linuxDoId
        ? legacyKey
        : '${legacyKey}_$id';
  }

  /// Hive/Notion/书签等按账号保存的数据同时加入站点维度。
  String scopedAccountId(String username) {
    if (id == DiscourseSiteRegistry.linuxDoId) return username;
    final encodedUsername = base64Url
        .encode(utf8.encode(username))
        .replaceAll('=', '');
    // 只使用 Hive box 安全字符，并用长保留前缀避免与 Linux.do 的历史
    // username box 撞名。旧实现的冒号会被部分存储层替换，Chat box 更会
    // 直接拒绝打开。
    return 'fluxdo_scoped_account_id_v1__${id}__$encodedUsername';
  }
}

/// 内置社区注册表。
class DiscourseSiteRegistry {
  DiscourseSiteRegistry._();

  static const String linuxDoId = 'linuxdo';
  static const String idcFlareId = 'idcflare';

  static final DiscourseSite linuxDo = DiscourseSite(
    id: linuxDoId,
    displayName: 'Linux.do',
    shortName: 'LINUX.DO',
    baseUrl: 'https://linux.do',
    description: '真诚、友善、团结、专业的技术社区',
    customization: linuxdoCustomization,
    supportsNativePasswordLogin: true,
    supportsBrowserAuthorizationLogin: true,
    supportsQrLogin: true,
    supportsChat: true,
    supportsLinuxDoEcosystem: true,
    supportsConnectStats: true,
    supportsSeeking: true,
    supportsLdcRewards: true,
    preferredLoginPath: '/login',
    challengePath: '/challenge',
  );

  static const DiscourseSite idcFlare = DiscourseSite(
    id: idcFlareId,
    displayName: 'IDC Flare',
    shortName: 'IDC FLARE',
    baseUrl: 'https://idcflare.com',
    description: '域名、主机等信息集散地',
    customization: idcflareCustomization,
    supportsNativePasswordLogin: false,
    supportsBrowserAuthorizationLogin: false,
    supportsQrLogin: false,
    supportsChat: false,
    supportsLinuxDoEcosystem: false,
    supportsConnectStats: false,
    supportsSeeking: false,
    supportsLdcRewards: false,
    preferredLoginPath: '/auth/oauth2_basic',
    // IDC Flare 没有专用 /challenge 页面，首页本身即可触发托管质询。
    challengePath: '/',
  );

  static final List<DiscourseSite> all = [linuxDo, idcFlare];

  static DiscourseSite get defaultSite => linuxDo;

  static DiscourseSite? byId(String? id) {
    if (id == null) return null;
    for (final site in all) {
      if (site.id == id) return site;
    }
    return null;
  }

  static DiscourseSite? byHost(String host) {
    for (final site in all) {
      if (site.matchesHost(host)) return site;
    }
    return null;
  }
}
