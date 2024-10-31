// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'analyzer_macro_tool.dart';
import 'cfe_macro_tool.dart';

final random = Random.secure();

/// Runs a Dart script with `dart_model` macros.
abstract class MacroTool {
  final String workspacePath;
  final String packageConfigPath;
  final String scriptPath;
  final bool skipCleanup;
  final bool skipMacros;
  final bool watch;
  final bool benchmark;
  final bool useParts;
  int benchmarkRuns = 6;

  MacroTool.internal(
      {required this.workspacePath,
      required this.packageConfigPath,
      required this.scriptPath,
      required this.skipCleanup,
      required this.skipMacros,
      required this.watch,
      required this.benchmark,
      required this.useParts});

  factory MacroTool(
          {required HostOption host,
          required String workspacePath,
          required String packageConfigPath,
          required String scriptPath,
          required bool skipCleanup,
          required bool skipMacros,
          required bool watch,
          required bool benchmark,
          required bool useParts}) =>
      host == HostOption.analyzer
          ? AnalyzerMacroTool(
              workspacePath: workspacePath,
              packageConfigPath: packageConfigPath,
              scriptPath: scriptPath,
              skipCleanup: skipCleanup,
              skipMacros: skipMacros,
              watch: watch,
              benchmark: benchmark,
              useParts: useParts)
          : CfeMacroTool(
              workspacePath: workspacePath,
              packageConfigPath: packageConfigPath,
              scriptPath: scriptPath,
              skipCleanup: skipCleanup,
              skipMacros: skipMacros,
              watch: watch,
              benchmark: benchmark,
              useParts: useParts);

  void show(String text) {
    if (!benchmark) print(text);
  }

  /// Shows a benchmark result.
  ///
  /// Returns `true` when enough results have been shown.
  bool showBenchmark(Stopwatch stopwatch) {
    if (!benchmark) return false;
    if (benchmark) stdout.write('${stopwatch.elapsedMilliseconds},');
    --benchmarkRuns;
    if (benchmarkRuns == 0) {
      print('');
      return true;
    } else {
      return false;
    }
  }

  Future<void> run() async {
    show('Running ${p.basename(scriptPath)} with macros on $this.');
    show('~~~');
    show('Package config: $packageConfigPath');
    show('Workspace: $workspacePath');
    show('Script: $scriptPath');

    // TODO(davidmorgan): make it an option to run with the CFE instead.
    final augmentedPaths = await augment();
    if (augmentedPaths.isEmpty) {
      show('No augmentation was generated, nothing to do, exiting.');
      exit(1);
    }

    for (final path in augmentedPaths) {
      _addImportAugment(path);
    }

    try {
      if (!benchmark) {
        show('~~~ running, output follows');
        final result = Process.runSync(
          Platform.resolvedExecutable,
          [
            'run',
            '--enable-experiment=macros',
            '--enable-experiment=enhanced-parts',
            '--packages=$packageConfigPath',
            scriptPath
          ],
          workingDirectory: workspacePath,
        );
        stdout.write(result.stdout);
        stderr.write(result.stderr);
        exitCode = result.exitCode;
      }
    } finally {
      if (skipCleanup) {
        show(
            '~~~ exit code $exitCode, skipping cleanup because --skip-cleanup');
      } else {
        show('~~~ exit code $exitCode, cleanup follows');
        // TODO: for all paths.
        _removeImportAugment();
        _removeAugmentations();
      }
    }

    // The analyzer seems to prevent exit.
    exit(exitCode);
  }

  /// The extension with which macro-generated augmentations will be written.
  String get augmentationFileExtension => '.macro_tool_output';

  /// Runs macros in [scriptFile] on the analyzer.
  ///
  /// Writes any augmentation to [augmentationFilePath].
  ///
  /// Returns the files that got augmented.
  Future<List<String>> augment();

  /// Deletes the augmentation file created by this tool.
  void _removeAugmentations() {
    //show('Deleting: $augmentationFilePath');
    //File(augmentationFilePath).deleteSync();
  }

  /// Adds `import augment` of the augmentation file.
  ///
  /// When macros run in the analyzer or CFE this inclusion of the augmentation
  /// output is automatic, but for `macro_tool` it has to be patched in.
  void _addImportAugment(String path) {
    show('Patching to import augmentations: $path');

    // Add the `import augment` or `part` statement.
    final partName = p.basename('$path$augmentationFileExtension');
    final line =
        "${useParts ? 'part ' : 'import augment'} '$partName'; $_addedMarker\n";

    final file = File(path);
    file.writeAsStringSync(_insertAfterLastImport(
        line, _removeToolAddedLinesFromSource(file.readAsStringSync())));
  }

  String _insertAfterLastImport(String line, String source) {
    final importRegexp = RegExp(r'^import .*;$', multiLine: true);
    final index = source.lastIndexOf(importRegexp);
    if (index == -1) return line + source;
    final nextLineIndex = index + source.substring(index).indexOf('\n') + 1;
    return source.substring(0, nextLineIndex) +
        line +
        source.substring(nextLineIndex);
  }

  /// Reverts the script file.
  void _removeImportAugment() {
    show('Reverting: $scriptPath');
    final file = File(scriptPath);
    file.writeAsStringSync(
        _removeToolAddedLinesFromSource(file.readAsStringSync()));
  }

  /// Returns [source] with lines added by [_addImportAugment] removed.
  String _removeToolAddedLinesFromSource(String source) =>
      source.split('\n').where((l) => !l.endsWith(_addedMarker)).join('\n');

  /// Updates the script to trigger macro rerun.
  ///
  /// The script must contain the string `CACHEBUSTER` in a place that triggers
  /// recomputation, for example in a field name.
  ///
  /// If there is an augmentation output file, updates that too.
  void cacheBustScript() {
    final token = random.nextInt(1 << 32).toRadixString(16) +
        random.nextInt(1 << 32).toRadixString(16);
    for (final path in [scriptPath, '$scriptPath$augmentationFileExtension']) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final source = file.readAsStringSync();
      final cacheBusterRegexp = RegExp('CACHEBUSTER[a-z0-9]*');
      if (path == scriptPath && !source.contains(cacheBusterRegexp)) {
        throw StateError(
            'Scripts for benchmarking should contain the string CACHEBUSTER '
            'which will be updated to trigger macro rerun.');
      }
      file.writeAsStringSync(
          source.replaceAll(cacheBusterRegexp, 'CACHEBUSTER$token'));
    }
  }
}

final String _addedMarker = '// added by macro_tool';

enum HostOption {
  analyzer,
  cfe;

  static HostOption? forString(String? option) => switch (option) {
        'analyzer' => HostOption.analyzer,
        'cfe' => HostOption.cfe,
        _ => null,
      };
}
