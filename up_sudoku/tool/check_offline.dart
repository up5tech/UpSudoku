/// Fails when the app stops being fully offline (AGENTS.md rule 2).
///
/// Checks, in order:
///  1. `pubspec.yaml` has no *direct* dependency that can reach the network.
///  2. `lib/` contains no network call and no URL audio source. (`audioplayers`
///     is allowed to pull `http` transitively because only `AssetSource` is
///     ever used; the code itself must never use a URL.)
///  3. The release `AndroidManifest.xml` — the Gradle merged one when the
///     project has been built, otherwise the source one — declares no
///     `android.permission.INTERNET`.
///  4. When a release APK exists, its compiled manifest declares no INTERNET
///     (uses `aapt2` from the Android SDK when it can be found).
///
/// ```bash
/// cd up_sudoku
/// dart run tool/check_offline.dart
/// ```
///
/// Exit code 0 = offline, 1 = something can reach the network.
library;

import 'dart:io';

/// Direct dependencies that would give the app a network capability.
const List<String> _forbiddenDependencies = [
  'http',
  'dio',
  'web_socket_channel',
  'graphql',
  'google_fonts', // downloads fonts at runtime
  'google_mobile_ads',
  'admob',
];

/// Dependency name prefixes that are always a network stack.
const List<String> _forbiddenPrefixes = ['firebase_', 'supabase_', 'sentry_'];

/// Source patterns that mean the app could reach the network at runtime.
final Map<String, RegExp> _forbiddenSource = {
  'package import': RegExp(
    r'''import\s+['"]package:(http|dio|web_socket_channel|graphql|google_fonts|firebase_[a-z_]+)/''',
  ),
  'URL audio source': RegExp(r'\bUrlSource\s*\(|setSourceUrl\s*\('),
  'HttpClient': RegExp(r'\bHttpClient\s*\('),
  'WebSocket': RegExp(r'\bWebSocket\.(connect|fromUrl)\s*\('),
  'raw socket': RegExp(r'\bSocket\.connect\s*\('),
};

final RegExp _internetPermission = RegExp(
  r'android\.permission\.INTERNET',
);

void main(List<String> args) {
  final project = _projectDirectory(args);
  final failures = <String>[];
  final notes = <String>[];
  final passed = <String>[];

  _checkDependencies(project, failures, passed);
  _checkSources(project, failures, passed);

  final sourceManifest = File(
    '${project.path}/android/app/src/main/AndroidManifest.xml',
  );
  if (sourceManifest.existsSync()) {
    _checkManifest('source manifest', sourceManifest, failures, passed);
  } else {
    failures.add('android/app/src/main/AndroidManifest.xml is missing');
  }

  final merged = _mergedReleaseManifest(project);
  if (merged != null) {
    _checkManifest('release manifest', merged, failures, passed);
  } else {
    notes.add(
      'no merged release manifest found; run `flutter build apk --release` '
      'to check the real artifact too',
    );
  }

  final apk = File(
    '${project.path}/build/app/outputs/flutter-apk/app-release.apk',
  );
  if (apk.existsSync()) {
    final aapt2 = _findAapt2();
    if (aapt2 == null) {
      notes.add('aapt2 not found; skipped the compiled APK manifest check');
    } else {
      final result = Process.runSync(aapt2, ['dump', 'permissions', apk.path]);
      final output = '${result.stdout}${result.stderr}';
      if (result.exitCode != 0) {
        failures
            .add('aapt2 could not read ${apk.path} (exit ${result.exitCode})');
      } else if (_internetPermission.hasMatch(output)) {
        failures.add('the release APK declares android.permission.INTERNET');
      } else {
        passed.add('release APK: no INTERNET permission');
      }
    }
  } else {
    notes.add('no release APK built; skipped the compiled manifest check');
  }

  final name = project.path
      .split(Platform.pathSeparator)
      .where((part) => part.isNotEmpty)
      .last;
  stdout.writeln('Offline check for $name');
  for (final note in notes) {
    stdout.writeln('  note  $note');
  }
  for (final line in passed) {
    stdout.writeln('  ok    $line');
  }
  if (failures.isEmpty) {
    stdout.writeln('All offline checks passed.');
    return;
  }
  for (final failure in failures) {
    stderr.writeln('  FAIL  $failure');
  }
  stderr.writeln('${failures.length} offline check(s) failed.');
  exitCode = 1;
}

/// The Flutter project directory, which is the parent of `tool/`.
Directory _projectDirectory(List<String> args) {
  final index = args.indexOf('--project');
  if (index >= 0 && index + 1 < args.length) {
    return Directory(args[index + 1]).absolute;
  }
  final script = Platform.script;
  final path =
      script.scheme == 'file' ? script.toFilePath() : File.fromUri(script).path;
  return Directory(path).parent.parent.absolute;
}

/// Rule 1: no direct network dependency in `pubspec.yaml`.
void _checkDependencies(
  Directory project,
  List<String> failures,
  List<String> passed,
) {
  final pubspec = File('${project.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    failures.add('pubspec.yaml is missing');
    return;
  }
  final direct = _directDependencies(pubspec.readAsStringSync());
  for (final name in direct) {
    final forbidden = _forbiddenDependencies.contains(name) ||
        _forbiddenPrefixes.any(name.startsWith);
    if (forbidden) {
      failures.add('pubspec.yaml declares `$name`, a network dependency');
    }
  }
  passed.add('pubspec.yaml: ${direct.length} direct dependencies, '
      'none network-capable');
}

/// Rule 2: no network call in the app's own Dart code.
void _checkSources(
  Directory project,
  List<String> failures,
  List<String> passed,
) {
  final lib = Directory('${project.path}/lib');
  if (!lib.existsSync()) {
    failures.add('lib/ is missing');
    return;
  }
  var scanned = 0;
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    scanned++;
    final source = entity.readAsStringSync();
    for (final entry in _forbiddenSource.entries) {
      if (entry.value.hasMatch(source)) {
        final relative = entity.path.substring(project.path.length + 1);
        failures.add('$relative uses ${entry.key}');
      }
    }
  }
  passed.add('lib/: $scanned files, no network calls');
}

/// Rule 3: a manifest must not request the INTERNET permission.
void _checkManifest(
  String label,
  File manifest,
  List<String> failures,
  List<String> passed,
) {
  final text = manifest.readAsStringSync();
  // Comments would otherwise match the documentation in the template.
  final live = text
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('<!--'))
      .join('\n')
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  if (_internetPermission.hasMatch(live)) {
    final relative = manifest.path;
    failures.add('$label ($relative) declares android.permission.INTERNET');
  } else {
    final relative =
        manifest.path.substring(manifest.path.indexOf('/android/') + 1);
    passed.add('$label: no INTERNET permission ($relative)');
  }
}

/// The Gradle-merged manifest of the release build, when one exists.
File? _mergedReleaseManifest(Directory project) {
  final intermediates = Directory('${project.path}/build/app/intermediates');
  if (!intermediates.existsSync()) return null;
  final candidates = intermediates
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('AndroidManifest.xml'))
      .where((file) => file.path.contains('merged_manifest'))
      .where((file) => file.path.contains('release'))
      .toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  return candidates.isEmpty ? null : candidates.first;
}

/// `aapt2` from the newest installed Android build-tools, if any.
String? _findAapt2() {
  final roots = <String>[
    if (Platform.environment['ANDROID_HOME'] != null)
      Platform.environment['ANDROID_HOME']!,
    if (Platform.environment['ANDROID_SDK_ROOT'] != null)
      Platform.environment['ANDROID_SDK_ROOT']!,
    '${Platform.environment['HOME'] ?? ''}/Library/Android/sdk',
    '${Platform.environment['HOME'] ?? ''}/Android/Sdk',
  ];
  for (final root in roots) {
    final tools = Directory('$root/build-tools');
    if (!tools.existsSync()) continue;
    final versions = tools
        .listSync()
        .whereType<Directory>()
        .map((dir) => dir.path)
        .toList()
      ..sort();
    for (final version in versions.reversed) {
      final aapt2 = File('$version/aapt2');
      if (aapt2.existsSync()) return aapt2.path;
    }
  }
  return null;
}

/// Names listed directly under `dependencies:` and `dev_dependencies:`.
///
/// A small line scanner instead of a YAML dependency: the pubspec shape is
/// stable and this keeps the check runnable with `dart run` alone.
Set<String> _directDependencies(String pubspec) {
  final names = <String>{};
  var inBlock = false;
  for (final raw in pubspec.split('\n')) {
    final withoutComment = raw.split('#').first.trimRight();
    if (withoutComment.trim().isEmpty) continue;
    final indent = withoutComment.length - withoutComment.trimLeft().length;
    final trimmed = withoutComment.trim();
    if (indent == 0) {
      inBlock = trimmed == 'dependencies:' || trimmed == 'dev_dependencies:';
      continue;
    }
    if (!inBlock || indent > 2) continue;
    final name = trimmed.split(':').first.trim();
    if (name.isNotEmpty) names.add(name);
  }
  return names;
}
