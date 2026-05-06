import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:moinsen_runapp/src/cli/state_file.dart';

/// Pre-grant iOS Simulator OR Android device privacy permissions for the
/// running app, so the system permission dialogs (Camera, Location, Photos,
/// etc.) never appear.
///
/// - **iOS**: wraps `xcrun simctl privacy <udid> grant <service> <bundle-id>`
/// - **Android**: wraps `adb -s <serial> shell pm grant <package> <perm>`
///
/// Platform is auto-detected from the device id format: 36-char hex-with-dashes
/// → iOS UDID; everything else → Android serial. App identifier (bundle id /
/// package id) is auto-detected from the project's iOS or Android build files
/// when not supplied. The set of services applies the same canonical names
/// across both platforms (camera, location, microphone, photos, ...) — this
/// command does the platform-specific name mapping internally.
///
/// Usage:
///   moinsen_run pregrant --services camera,location
///   moinsen_run pregrant --services camera --bundle-id com.example.app
///   moinsen_run pregrant --services photos --device `<id>`
class PregrantCommand extends Command<void> {
  PregrantCommand() {
    argParser
      ..addOption(
        'device',
        abbr: 'd',
        help: 'Simulator UDID (iOS) or adb serial (Android). Default: read '
            'from .moinsen_run.json.',
      )
      ..addOption(
        'bundle-id',
        abbr: 'b',
        help: 'iOS bundle id / Android applicationId of the app. Default: '
            'auto-detect from ios/Runner.xcodeproj or '
            'android/app/build.gradle{,.kts}.',
      )
      ..addMultiOption(
        'services',
        abbr: 's',
        help: 'Privacy services to pre-grant. Comma-separated '
            '(`--services camera,photos`) or repeated '
            '(`--services camera --services photos`). Canonical service '
            'names are mapped to the right OS permission identifier per '
            'platform.',
        defaultsTo: const [
          'camera',
          'photos',
          'photos-add',
          'microphone',
          'location',
          'location-always',
          'media-library',
          'motion',
          'contacts-limited',
        ],
        allowed: _allowedServices,
      );
  }

  // Canonical service names accepted by --services. Same list whether the
  // host runs iOS or Android — the platform mapping below picks the right
  // OS-level identifier (or skips silently if N/A on the platform).
  static const _allowedServices = <String>[
    'all',
    'calendar',
    'contacts-limited',
    'contacts',
    'location',
    'location-always',
    'photos-add',
    'media-library',
    'photos',
    'motion',
    'microphone',
    'siri',
    'speech',
    'camera',
    'reminders',
    'home',
    'media-add',
    'health-share',
    'health-update',
  ];

  // Canonical → Android permission strings. Keys absent here have no
  // Android counterpart and are skipped on Android (failed with note).
  static const _androidPermissionMap = <String, String>{
    'camera': 'android.permission.CAMERA',
    'microphone': 'android.permission.RECORD_AUDIO',
    'location': 'android.permission.ACCESS_FINE_LOCATION',
    'location-always': 'android.permission.ACCESS_BACKGROUND_LOCATION',
    'contacts': 'android.permission.READ_CONTACTS',
    'contacts-limited': 'android.permission.READ_CONTACTS',
    'calendar': 'android.permission.READ_CALENDAR',
    'photos': 'android.permission.READ_MEDIA_IMAGES',
    'media-library': 'android.permission.READ_MEDIA_AUDIO',
    'motion': 'android.permission.ACTIVITY_RECOGNITION',
  };

  @override
  String get name => 'pregrant';

  @override
  String get description =>
      'Pre-grant system permissions so dialogs never appear (iOS Sim or '
      'Android device).';

  @override
  Future<void> run() async {
    final services = (argResults?['services'] as List<dynamic>? ?? const [])
        .cast<String>();
    if (services.isEmpty) {
      stderr.writeln(jsonEncode({'error': '--services list cannot be empty'}));
      exit(1);
    }

    final deviceId = (argResults?['device'] as String?) ??
        _deviceIdFromStateFile();
    if (deviceId == null) {
      stderr.writeln(
        jsonEncode({
          'error': 'No --device given and no .moinsen_run.json present. '
              'Run `moinsen_run start -d <id>` first or pass --device.',
        }),
      );
      exit(1);
    }

    final platform = _detectPlatform(deviceId);
    final result = switch (platform) {
      _Platform.ios => await _runIos(deviceId, services),
      _Platform.android => await _runAndroid(deviceId, services),
    };

    stdout.writeln(jsonEncode(result));
    exit((result['granted'] as List).isEmpty ? 1 : 0);
  }

  /// 36-char hex-with-dashes → iOS UDID. Anything else → Android adb serial.
  _Platform _detectPlatform(String deviceId) {
    final iosUdid = RegExp(r'^[0-9A-F-]{36}$', caseSensitive: false);
    return iosUdid.hasMatch(deviceId) ? _Platform.ios : _Platform.android;
  }

  Future<Map<String, dynamic>> _runIos(
    String udid,
    List<String> services,
  ) async {
    if (!Platform.isMacOS) {
      return {
        'error': 'iOS pregrant requires macOS (xcrun simctl).',
        'granted': const <String>[],
        'failed': const <Map<String, String>>[],
      };
    }

    final bundleId =
        (argResults?['bundle-id'] as String?) ?? await _detectIosBundleId();
    if (bundleId == null) {
      return {
        'error': 'Could not auto-detect iOS bundle id. Pass --bundle-id.',
        'granted': const <String>[],
        'failed': const <Map<String, String>>[],
      };
    }

    final granted = <String>[];
    final failed = <Map<String, String>>[];
    for (final service in services) {
      final result = Process.runSync(
        'xcrun',
        ['simctl', 'privacy', udid, 'grant', service, bundleId],
      );
      if (result.exitCode == 0) {
        granted.add(service);
      } else {
        failed.add({
          'service': service,
          'error': (result.stderr as String).trim().isEmpty
              ? 'exit ${result.exitCode}'
              : (result.stderr as String).trim(),
        });
      }
    }
    return {
      'platform': 'ios',
      'udid': udid,
      'bundleId': bundleId,
      'granted': granted,
      'failed': failed,
    };
  }

  Future<Map<String, dynamic>> _runAndroid(
    String serial,
    List<String> services,
  ) async {
    final packageId = (argResults?['bundle-id'] as String?) ??
        await _detectAndroidApplicationId();
    if (packageId == null) {
      return {
        'error': 'Could not auto-detect Android applicationId. '
            'Pass --bundle-id (a.k.a. applicationId).',
        'granted': const <String>[],
        'failed': const <Map<String, String>>[],
      };
    }

    final granted = <String>[];
    final failed = <Map<String, String>>[];
    for (final service in services) {
      final perm = _androidPermissionMap[service];
      if (perm == null) {
        failed.add({
          'service': service,
          'error': 'No Android counterpart for "$service" — skipped.',
        });
        continue;
      }
      final result = Process.runSync(
        'adb',
        ['-s', serial, 'shell', 'pm', 'grant', packageId, perm],
      );
      if (result.exitCode == 0) {
        granted.add(service);
      } else {
        // adb returns the OS error in stdout for `pm grant` (not stderr).
        final out = (result.stdout as String).trim();
        final err = (result.stderr as String).trim();
        failed.add({
          'service': service,
          'error': err.isNotEmpty
              ? err
              : (out.isNotEmpty ? out : 'exit ${result.exitCode}'),
        });
      }
    }
    return {
      'platform': 'android',
      'serial': serial,
      'packageId': packageId,
      'granted': granted,
      'failed': failed,
    };
  }

  String? _deviceIdFromStateFile() {
    final state = readStateFile(
      path: '${Directory.current.path}/.moinsen_run.json',
    );
    if (state == null) return null;
    final id = state.device;
    // Already-resolved UDID/serial → use as-is.
    final iosUdid = RegExp(r'^[0-9A-F-]{36}$', caseSensitive: false);
    if (iosUdid.hasMatch(id)) return id;
    // Pure-digits or alphanum without dashes → likely an Android serial.
    final androidSerial = RegExp(r'^[A-Z0-9]{6,}$', caseSensitive: false);
    if (androidSerial.hasMatch(id)) return id;
    // Otherwise assume it's a sim "name" and try simctl-resolution.
    return _resolveSimulatorUdid(id);
  }

  String? _resolveSimulatorUdid(String name) {
    if (!Platform.isMacOS) return null;
    final result = Process.runSync(
      'xcrun',
      ['simctl', 'list', '-j', 'devices'],
    );
    if (result.exitCode != 0) return null;
    try {
      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final devices = json['devices'] as Map<String, dynamic>? ?? {};
      for (final runtimeDevices in devices.values) {
        if (runtimeDevices is! List) continue;
        for (final device in runtimeDevices) {
          if (device is! Map) continue;
          if (device['name'] == name && device['state'] == 'Booted') {
            return device['udid'] as String?;
          }
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  Future<String?> _detectIosBundleId() async {
    final iosDir = Directory('${Directory.current.path}/ios');
    if (!iosDir.existsSync()) return null;
    final pbxproj = File('${iosDir.path}/Runner.xcodeproj/project.pbxproj');
    if (!pbxproj.existsSync()) return null;
    final content = await pbxproj.readAsString();
    final match = RegExp(
      r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);',
    ).firstMatch(content);
    if (match == null) return null;
    return match
        .group(1)
        ?.replaceAll('"', '')
        .replaceAll(r'$(PRODUCT_NAME)', 'Runner')
        .trim();
  }

  Future<String?> _detectAndroidApplicationId() async {
    final androidDir = Directory('${Directory.current.path}/android');
    if (!androidDir.existsSync()) return null;
    // Try build.gradle.kts first (modern), then build.gradle.
    for (final file in [
      File('${androidDir.path}/app/build.gradle.kts'),
      File('${androidDir.path}/app/build.gradle'),
    ]) {
      if (!file.existsSync()) continue;
      final content = await file.readAsString();
      final match = RegExp(
        r'''applicationId\s*[=]?\s*["']([^"']+)["']''',
      ).firstMatch(content);
      if (match != null) return match.group(1);
    }
    return null;
  }
}

enum _Platform { ios, android }
