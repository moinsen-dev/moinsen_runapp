import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:moinsen_runapp/src/cli/state_file.dart';

/// Pre-grant iOS Simulator privacy permissions for the running app, so the
/// system permission dialogs (Camera, Location, Photos, etc.) never appear.
///
/// Wraps `xcrun simctl privacy <udid> grant <service> <bundle-id>` per
/// service. Bundle-id is auto-detected from the active iOS build settings if
/// not supplied. UDID is auto-detected from `.moinsen_run.json` (set by
/// `moinsen_run start`) when omitted.
///
/// Usage:
///   moinsen_run pregrant --services camera location
///   moinsen_run pregrant --services camera --bundle-id com.example.app
///   moinsen_run pregrant --services photos --device `<udid>`
///
/// Returns JSON `{granted: [...], failed: [{service, error}]}`. Exits 0 if
/// at least one service was granted, 1 if all failed.
class PregrantCommand extends Command<void> {
  PregrantCommand() {
    argParser
      ..addOption(
        'device',
        abbr: 'd',
        help: 'Simulator UDID (default: read from .moinsen_run.json).',
      )
      ..addOption(
        'bundle-id',
        abbr: 'b',
        help: 'iOS bundle id of the app (default: auto-detect from xcodebuild '
            'showBuildSettings; falls back to PRODUCT_BUNDLE_IDENTIFIER).',
      )
      ..addMultiOption(
        'services',
        abbr: 's',
        help: 'Privacy services to pre-grant. Comma-separated '
            '(`--services camera,photos`) or repeated '
            '(`--services camera --services photos`). See '
            '`xcrun simctl privacy --help` for the canonical list.',
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
        allowed: const [
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
        ],
      );
  }

  @override
  String get name => 'pregrant';

  @override
  String get description =>
      'Pre-grant iOS Simulator privacy permissions so dialogs never appear.';

  @override
  Future<void> run() async {
    if (!Platform.isMacOS) {
      stderr.writeln(
        jsonEncode({'error': 'pregrant only supports iOS Simulator on macOS'}),
      );
      exit(1);
    }

    final services = (argResults?['services'] as List<dynamic>? ?? const [])
        .cast<String>();
    if (services.isEmpty) {
      stderr.writeln(jsonEncode({'error': '--services list cannot be empty'}));
      exit(1);
    }

    final udid = (argResults?['device'] as String?) ?? _udidFromStateFile();
    if (udid == null) {
      stderr.writeln(
        jsonEncode({
          'error': 'No --device given and no .moinsen_run.json present. '
              'Run `moinsen_run start -d <udid>` first or pass --device.',
        }),
      );
      exit(1);
    }

    final bundleId =
        (argResults?['bundle-id'] as String?) ?? await _detectBundleId();
    if (bundleId == null) {
      stderr.writeln(
        jsonEncode({
          'error': 'Could not auto-detect bundle id. Pass --bundle-id.',
        }),
      );
      exit(1);
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

    stdout.writeln(
      jsonEncode({
        'udid': udid,
        'bundleId': bundleId,
        'granted': granted,
        'failed': failed,
      }),
    );
    exit(granted.isEmpty ? 1 : 0);
  }

  String? _udidFromStateFile() {
    final state = readStateFile(
      path: '${Directory.current.path}/.moinsen_run.json',
    );
    if (state == null) return null;
    // The state file stores the device *name* from `flutter run`, not a UDID.
    // If it looks like a UDID (hex with dashes) we use it; otherwise we ask
    // simctl to resolve it.
    final udidRegex = RegExp(r'^[0-9A-F-]{36}$', caseSensitive: false);
    if (udidRegex.hasMatch(state.device)) {
      return state.device;
    }
    return _resolveSimulatorUdid(state.device);
  }

  String? _resolveSimulatorUdid(String name) {
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

  Future<String?> _detectBundleId() async {
    final iosDir = Directory('${Directory.current.path}/ios');
    if (!iosDir.existsSync()) return null;
    // Try Runner.xcodeproj/project.pbxproj — looks for PRODUCT_BUNDLE_IDENTIFIER.
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
}
