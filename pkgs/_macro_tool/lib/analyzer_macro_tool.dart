// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:_analyzer_macros/macro_implementation.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/src/summary2/macro_injected_impl.dart'
    as injected_analyzer;
import 'package:macro_service/macro_service.dart';

import 'macro_tool.dart';

class AnalyzerMacroTool extends MacroTool {
  AnalyzerMacroTool(
      {required super.workspacePath,
      required super.packageConfigPath,
      required super.scriptPath,
      required super.skipCleanup,
      required super.skipMacros,
      required super.watch,
      required super.benchmark,
      required super.useParts})
      : super.internal();

  @override
  Future<List<String>> augment() async {
    if (watch && benchmark) {
      throw UnimplementedError(
          '--watch and --benchmark cannot be used together');
    }

    // If benchmarking, modify the script before doing anything to get a
    // meaningful "initial analysis" number.
    if (benchmark) {
      cacheBustScript();
    }

    final result = <String>[];

    final contextCollection =
        AnalysisContextCollection(includedPaths: [workspacePath]);
    final analysisContext = contextCollection.contexts.first;

    if (!skipMacros) {
      injected_analyzer.macroImplementation =
          await AnalyzerMacroImplementation.start(
              protocol: Protocol(
                  encoding: ProtocolEncoding.binary,
                  version: ProtocolVersion.macros1),
              packageConfig: Uri.file(packageConfigPath));
    }

    final paths = File(scriptPath)
        .parent
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('.dart'))
        .toList()
      ..sort();

    List<ResolvedLibraryResult> resolvedLibraries = [];
    // `asBroadcastStream` so repeated use of `first` below waits for the next
    // change.
    var events = File(scriptPath).watch().asBroadcastStream();
    var stopwatch = Stopwatch()..start();
    while (true) {
      for (final path in paths) {
        resolvedLibraries.add(await analysisContext.currentSession
            .getResolvedLibrary(path) as ResolvedLibraryResult);
        final resolvedLibrary = resolvedLibraries.last;

        show('Resolved in ${stopwatch.elapsedMilliseconds}ms.');
        if (path == paths.first && showBenchmark(stopwatch)) return result;

//      for (final resolvedLibrary in resolvedLibraries) {
        final errors = (await analysisContext.currentSession.getErrors(path))
            as ErrorsResult;
        final actualErrors =
            errors.errors.where((e) => e.severity == Severity.error).toList();
        if (actualErrors.isNotEmpty) {
          // Display during benchmarks too, so `print` not `show`.
          print('Errors: $actualErrors');
        }

        final augmentationUnits =
            resolvedLibrary.units.where((u) => u.isMacroPart).toList();
        if (augmentationUnits.isNotEmpty) {
          result.add(path);

          final augmentationFilePath = '$path$augmentationFileExtension';
          show('Macro output (patched to use augment library): '
              '$augmentationFilePath');
          var content = augmentationUnits.single.content;
          // The analyzer produces augmentations in parts, but the CFE still
          // wants them in augmentation libraries. Adjust the output if needed.
          if (!useParts) {
            content = content.replaceAll('part of', 'augment library');
          }
          File(augmentationFilePath).writeAsStringSync(content);
        }
      }

      if (!watch && !benchmark) return result;

      if (watch) {
        show('Running with --watch, waiting for next change to script.');
        await events.first;
        show('Script changed, rerunning macro.');
      } else {
        cacheBustScript();
      }
      stopwatch.reset();
      analysisContext.changeFile(scriptPath);
      if (skipMacros) {
        analysisContext.changeFile('$scriptPath$augmentationFileExtension');
      }
      await analysisContext.applyPendingFileChanges();
    }
  }

  @override
  String toString() => 'analyzer';
}
