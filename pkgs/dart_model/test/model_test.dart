// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:dart_model/dart_model.dart';
import 'package:test/test.dart';

void main() {
  for (final scope in [DartModelScope.none, DartModelScope('test')]) {
    group('Model in scope $scope', () {
      late Model model;

      setUp(() {
        scope.runSync(() {
          model = Model();
          final library = Library();
          model.uris['package:dart_model/dart_model.dart'] = library;
          final interface = Interface(
              properties: Properties(isClass: true),
              metadataAnnotations: [
                MetadataAnnotation(
                    type: QualifiedName(
                        'package:dart_model/dart_model.dart#SomeAnnotation'))
              ]);
          library.scopes['JsonData'] = interface;
          interface.members['_root'] = Member(
            properties: Properties(isField: true),
          );
        });
      });

      final expected = {
        'uris': {
          'package:dart_model/dart_model.dart': {
            'scopes': {
              'JsonData': {
                'metadataAnnotations': [
                  {'type': 'package:dart_model/dart_model.dart#SomeAnnotation'}
                ],
                'members': {
                  '_root': {
                    'properties': {'isField': true}
                  }
                },
                'properties': {'isClass': true}
              }
            }
          }
        }
      };

      test('underlying map is of expected type for scope', () {
        if (scope == DartModelScope.none) {
          // If no scope, it's an SDK map.
          expect(model.node.runtimeType.toString(), '_Map<String, Object?>');
        } else {
          // If in scope, it's backed by a buffer.
          expect(model.node.runtimeType.toString(), '_TypedMap');
        }
      });

      test('maps to JSON', () {
        expect(model as Map, expected);
      });

      test('maps to JSON after deserialization', () {
        final deserializedModel = Model.fromJson(
            json.decode(json.encode(model as Map)) as Map<String, Object?>);
        expect(deserializedModel as Map, expected);
      });

      test('maps can be accessed as fields', () {
        expect(model.uris['package:dart_model/dart_model.dart'],
            expected['uris']!['package:dart_model/dart_model.dart']);
        expect(
            model
                .uris['package:dart_model/dart_model.dart']!.scopes['JsonData'],
            expected['uris']!['package:dart_model/dart_model.dart']!['scopes']![
                'JsonData']);
        expect(
            model.uris['package:dart_model/dart_model.dart']!
                .scopes['JsonData']!.properties,
            expected['uris']!['package:dart_model/dart_model.dart']!['scopes']![
                'JsonData']!['properties']);
      });

      test('maps can be accessed as fields after deserialization', () {
        final deserializedModel = Model.fromJson(
            json.decode(json.encode(model as Map)) as Map<String, Object?>);

        expect(
            deserializedModel.uris['package:dart_model/dart_model.dart']!
                .scopes['JsonData']!.properties,
            expected['uris']!['package:dart_model/dart_model.dart']!['scopes']![
                'JsonData']!['properties']);
      });

      test('lists can be accessed as fields', () {
        expect(
            model.uris['package:dart_model/dart_model.dart']!
                .scopes['JsonData']!.members,
            expected['uris']!['package:dart_model/dart_model.dart']!['scopes']![
                'JsonData']!['members']);
      });

      test('lists can be accessed as fields after deserialization', () {
        final deserializedModel = Model.fromJson(
            json.decode(json.encode(model as Map)) as Map<String, Object?>);

        expect(
            deserializedModel.uris['package:dart_model/dart_model.dart']!
                .scopes['JsonData']!.members,
            expected['uris']!['package:dart_model/dart_model.dart']!['scopes']![
                'JsonData']!['members']);
      });
    });
  }

  group(QualifiedName, () {
    test('has uri', () {
      expect(QualifiedName('package:foo/foo.dart#Foo').uri,
          'package:foo/foo.dart');
    });

    test('has name', () {
      expect(QualifiedName('package:foo/foo.dart#Foo').name, 'Foo');
    });
  });
}
