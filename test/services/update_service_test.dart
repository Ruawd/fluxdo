import 'package:flutter_test/flutter_test.dart';
import 'package:fluxdo/services/update_service.dart';

void main() {
  test('专用 iOS 标签可以解析为语义版本', () {
    expect(UpdateService.normalizeReleaseVersion('ios-v0.2.28'), '0.2.28');
    expect(UpdateService.normalizeReleaseVersion('v1.4.0'), '1.4.0');
  });

  test('版本比较兼容 ios-v 前缀和短版本号', () {
    expect(
      UpdateService.compareVersions('ios-v0.2.28', '0.2.27'),
      greaterThan(0),
    );
    expect(UpdateService.compareVersions('0.2.28', 'ios-v0.2.28'), 0);
    expect(UpdateService.compareVersions('1.0', '0.9.9'), greaterThan(0));
  });

  test('无法识别的标签明确报错', () {
    expect(
      () => UpdateService.normalizeReleaseVersion('latest'),
      throwsFormatException,
    );
  });
}
