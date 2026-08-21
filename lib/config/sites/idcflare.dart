import '../site_customization.dart';

/// IDC Flare 站点自定义配置。
///
/// IDC Flare 与 Linux.do 同为 Discourse，但不复用 Linux.do 的头像光晕、
/// 特殊头衔和外链黑名单，避免把一个社区的主题规则错误套到另一个社区。
const idcflareCustomization = SiteCustomization(
  linkSecurityConfig: LinkSecurityConfig(
    enableExitConfirmation: true,
    internalDomains: [
      '*.idcflare.com',
      'localhost',
      '*.local',
      '^127(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}',
      '^10(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){3}',
      '^192\\.168(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){2}',
      '^172\\.(?:1[6-9]|2\\d|3[0-1])(?:\\.(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)){2}',
    ],
    trustedDomains: ['*.linux.do', 't.me/idcflare'],
    riskyDomains: [
      'bit.ly',
      'tinyurl.com',
      't.co',
      'goo.gl',
      'is.gd',
      'tiny.cc',
      'v.gd',
      'link.zip',
    ],
    dangerousDomains: ['**aff='],
  ),
);
