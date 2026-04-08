import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

/// Install the moinsen_runapp AI agent skill into a Claude/Cursor skills
/// directory.
///
/// By default installs to the project-level `.claude/skills/` directory.
/// Use `--global` for the user-level `~/.claude/skills/` directory.
/// Use `--ide cursor` to target `.cursor/skills/` instead.
class InstallSkillCommand extends Command<void> {
  InstallSkillCommand() {
    argParser
      ..addFlag(
        'global',
        abbr: 'g',
        help: 'Install to user-level skills directory (~/.claude/skills/)',
      )
      ..addOption(
        'ide',
        defaultsTo: 'claude',
        allowed: ['claude', 'cursor'],
        help: 'Target IDE',
      );
  }

  @override
  String get name => 'install-skill';

  @override
  String get description =>
      'Install the moinsen_runapp AI agent skill for Claude Code or Cursor.';

  @override
  Future<void> run() async {
    final global = argResults!.flag('global');
    final ide = argResults!['ide'] as String;

    final skillContent = _readSkillMd();
    if (skillContent == null) {
      stderr
        ..writeln('Error: Could not locate SKILL.md in package.')
        ..writeln(
          'Ensure moinsen_runapp is a dependency and run `flutter pub get`.',
        );
      exit(1);
    }

    final targetDir = _targetDirectory(global: global, ide: ide);
    final skillDir = Directory('$targetDir/moinsen_runapp-skill');
    final skillFile = File('${skillDir.path}/SKILL.md');

    skillDir.createSync(recursive: true);
    skillFile.writeAsStringSync(skillContent);

    final dotDir = ide == 'cursor' ? '.cursor' : '.claude';
    final location = global ? 'global (~/$dotDir/skills/)' : 'project';
    stdout
      ..writeln('Installed moinsen_runapp-skill to $location')
      ..writeln('  ${skillFile.path}');
  }

  String _targetDirectory({required bool global, required String ide}) {
    final dotDir = ide == 'cursor' ? '.cursor' : '.claude';

    if (global) {
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home == null) {
        stderr.writeln('Error: Could not determine home directory.');
        exit(1);
      }
      return '$home/$dotDir/skills';
    }

    return '${Directory.current.path}/$dotDir/skills';
  }

  /// Reads SKILL.md by locating the moinsen_runapp package on disk.
  ///
  /// Resolves the package path from `.dart_tool/package_config.json`
  /// (the standard Dart package resolution mechanism).
  String? _readSkillMd() {
    const relative = 'skills/moinsen_runapp-skill/SKILL.md';

    // Strategy 1: resolve from package_config.json in current project.
    final packageRoot = _resolvePackageRoot();
    if (packageRoot != null) {
      final file = File('$packageRoot/$relative');
      if (file.existsSync()) return file.readAsStringSync();
    }

    // Strategy 2: navigate from the running script (bin/ -> root).
    final scriptFile = File.fromUri(Platform.script);
    if (scriptFile.existsSync()) {
      final root = scriptFile.parent.parent;
      final file = File('${root.path}/$relative');
      if (file.existsSync()) return file.readAsStringSync();
    }

    return null;
  }

  /// Resolves moinsen_runapp package root from package_config.json.
  String? _resolvePackageRoot() {
    final configFile = File(
      '${Directory.current.path}/.dart_tool/package_config.json',
    );
    if (!configFile.existsSync()) return null;

    try {
      final config =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      final packages = config['packages'] as List<dynamic>?;
      if (packages == null) return null;

      for (final pkg in packages) {
        final p = pkg as Map<String, dynamic>;
        if (p['name'] == 'moinsen_runapp') {
          final rootUri = p['rootUri'] as String;
          // rootUri can be relative (../../../.pub-cache/...) or absolute
          // (file:///...).
          if (rootUri.startsWith('file://')) {
            return Uri.parse(rootUri).toFilePath();
          }
          // Relative to .dart_tool/
          final dartToolDir = configFile.parent;
          final resolved = Directory(
            '${dartToolDir.path}/$rootUri',
          );
          if (resolved.existsSync()) {
            return resolved.resolveSymbolicLinksSync();
          }
          return null;
        }
      }
    } on Object {
      // Ignore parse errors.
    }
    return null;
  }
}
