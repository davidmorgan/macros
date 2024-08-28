// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'json_buffer/json_buffer_builder.dart';

class DartModelScope {
  static final DartModelScope none = DartModelScope('none');

  final String name;

  DartModelScope(this.name);

  static const _symbol = #_dartModelScope;

  static DartModelScope get current => _currentOrNull ?? none;

  static DartModelScope? get _currentOrNull =>
      Zone.current[_symbol] as DartModelScope?;

  Future<void> run(Future<void> Function() function) async {
    await runZoned(function, zoneValues: {_symbol: this});
  }

  void runSync(void Function() function) {
    runZoned(function, zoneValues: {_symbol: this});
  }

  static Map<String, Object?> createMap(TypedMapSchema schema,
      [Object? v0,
      Object? v1,
      Object? v2,
      Object? v3,
      Object? v4,
      Object? v5,
      Object? v6,
      Object? v7]) {
    final scope = current;
    if (scope == none) {
      return schema.createMap(v0, v1, v2, v3, v4, v5, v6, v7);
    } else {
      return scope.responseBuilder
          .createTypedMap(schema, v0, v1, v2, v3, v4, v5, v6, v7);
    }
  }

  static Map<String, V> createGrowableMap<V>() {
    final scope = current;
    if (scope == none) {
      return <String, V>{};
    } else {
      return scope.responseBuilder.createGrowableMap<V>();
    }
  }

  final JsonBufferBuilder _responseBuilder = JsonBufferBuilder();
  JsonBufferBuilder get responseBuilder {
    if (this == none) {
      throw StateError('No scope, no responseBuilder!');
    }
    return _responseBuilder;
  }

  @override
  String toString() => 'DartModelScope($name)';
}
