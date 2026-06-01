/// App version metadata embedded in backup manifests.
///
/// [package_info_plus] is not wired yet; values mirror [pubspec.yaml] `version`
/// (currently `1.0.0+1`). Update manually when releasing until runtime lookup exists.
abstract final class BackupAppInfo {
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
}
