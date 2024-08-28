// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dart_model/dart_model.dart';
import 'package:test/test.dart';

void main() {
  group(DartModelScope, () {
    test('current returns none scope by default', () {
      expect(DartModelScope.current, DartModelScope.none);
    });

    test('current is set on run', () async {
      final scope = DartModelScope('test');
      await scope.run(() async {
        expect(identical(DartModelScope.current, scope), true);
      });
    });

    test('current is set on runSync', () async {
      final scope = DartModelScope('test');
      scope.runSync(() {
        expect(identical(DartModelScope.current, scope), true);
      });
    });

    test('two concurrent requests get correct scope', () async {
      final scope1 = DartModelScope('scope1');
      final scope2 = DartModelScope('scope2');

      final future1 = scope1.run(() async {
        expect(identical(DartModelScope.current, scope1), true);
      });
      final future2 = scope2.run(() async {
        expect(identical(DartModelScope.current, scope2), true);
      });

      await Future.wait(<Future<void>>[future1, future2]);
    });
  });
}
