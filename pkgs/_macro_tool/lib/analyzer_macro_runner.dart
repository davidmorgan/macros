// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:_analyzer_macros/macro_implementation.dart';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart' hide FileResult;
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/src/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/src/summary2/macro_injected_impl.dart'
    as injected_analyzer;
import 'package:analyzer/src/util/performance/operation_performance.dart';
import 'package:macro_service/macro_service.dart';

import 'macro_runner.dart';
import 'source_file.dart';

class AnalyzerMacroRunner implements MacroRunner {
  final String workspacePath;
  final String packageConfigPath;

  @override
  final List<SourceFile> sourceFiles;

  late final AnalysisContextCollection analysisContextCollection;
  late final AnalysisContext analysisContext;
  AnalyzerMacroImplementation? analyzerMacroImplementation;

  AnalyzerMacroRunner(
      {required this.workspacePath, required this.packageConfigPath})
      : sourceFiles = Directory(workspacePath)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .map((f) => SourceFile(f.path))
            .toList() {
    analysisContextCollection =
        AnalysisContextCollection(includedPaths: [workspacePath]);
    analysisContext = analysisContextCollection.contexts.first;
  }

  void notifyChange(SourceFile sourceFile) {
    analysisContext.changeFile(sourceFile.path);
  }

  @override
  Future<WorkspaceResult> run({bool injectImplementation = true}) async {
    if (injectImplementation) {
      analyzerMacroImplementation ??= await AnalyzerMacroImplementation.start(
          protocol: Protocol(
              encoding: ProtocolEncoding.binary,
              version: ProtocolVersion.macros1),
          packageConfig: Uri.file(packageConfigPath));
      injected_analyzer.macroImplementation = analyzerMacroImplementation;
    } else {
      injected_analyzer.macroImplementation = null;
    }

    (analysisContextCollection as AnalysisContextCollectionImpl)
        .scheduler
        .accumulatedPerformance = OperationPerformanceImpl('<scheduler>');

    final fileResults = <FileResult>[];
    final stopwatch = Stopwatch()..start();
    Duration? firstDuration;
    for (final sourceFile in sourceFiles) {
      await analysisContext.applyPendingFileChanges();
      ResolvedLibraryResult resolvedLibrary =
          (await analysisContext.currentSession.getResolvedLibrary(sourceFile))
              as ResolvedLibraryResult;

      final errors = ((await analysisContext.currentSession
              .getErrors(sourceFile)) as ErrorsResult)
          .errors
          .where((e) => e.severity == Severity.error)
          .map((e) => e.toString())
          .toList();

      final augmentationUnits =
          resolvedLibrary.units.where((u) => u.isMacroPart).toList();
      final output = augmentationUnits.singleOrNull?.content;

      fileResults.add(
          FileResult(sourceFile: sourceFile, output: output, errors: errors));
      if (firstDuration == null) firstDuration = stopwatch.elapsed;
    }

    final buffer = StringBuffer();
    (analysisContextCollection as AnalysisContextCollectionImpl)
        .scheduler
        .accumulatedPerformance
        .write2(buffer: buffer);
    print(buffer);

    return WorkspaceResult(
        fileResults: fileResults,
        firstResultAfter: firstDuration!,
        lastResultAfter: stopwatch.elapsed);
  }
}

extension X on OperationPerformanceImpl {
  void write2({required StringBuffer buffer, String indent = ''}) {
    buffer.write(
        '$name,$count,${elapsed.inMilliseconds},${elapsedSelf.inMilliseconds}');

    /*final data = this.data;
    if (data.isNotEmpty) {
      buffer.write('[${data.map((d) => d.toString2()).join(', ')}]');
    }*/

    buffer.writeln();

    var childIndent = '$indent  ';
    for (var child in children) {
      (child as OperationPerformanceImpl)
          .write2(buffer: buffer, indent: childIndent);
    }
  }
}

extension Y on OperationPerformanceData {
  String toString2() {
    if (value is Duration) return (value as Duration).inMilliseconds.toString();
    return value.toString();
  }
}
