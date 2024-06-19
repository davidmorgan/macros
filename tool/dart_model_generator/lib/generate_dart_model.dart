// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:json_schema/json_schema.dart';

/// Generates `pkgs/dart_model/lib/src/dart_model.g.dart` from
/// `schemas/dart_model.schema.json`.
///
/// Generated types are extension types with JSON maps as the underlying data.
/// They have a `fromJson` constructor that takes that JSON, and a no-name
/// constructor that builds it.
void run() {
  final result = StringBuffer();
  final schema = JsonSchema.create(
      File('schemas/dart_model.schema.json').readAsStringSync());
  for (final def in schema.defs.entries) {
    result.writeln(_generateExtensionType(def.key, def.value));
  }

  final formattedResult =
      DartFormatter().formatSource(SourceCode(result.toString())).text;
  _mergeCode(File('pkgs/dart_model/lib/src/dart_model.dart'), formattedResult);
}

String _generateExtensionType(String name, JsonSchema definition) {
  final result = StringBuffer();

  // Generate the extension type header with `fromJson` constructor and the
  // appropriate underlying type.
  final jsonType = switch (definition.type) {
    SchemaType.object => 'Map<String, Object?> node',
    SchemaType.string => 'String string',
    _ => throw UnsupportedError('Schema type ${definition.type}.'),
  };
  result.writeln('extension type $name.fromJson($jsonType) {');

  // Generate the non-JSON constructor, which accepts an optional value for
  // every field and constructs JSON from it.
  final propertyMetadatas = [
    for (var e in definition.properties.entries)
      _readPropertyMetadata(e.key, e.value)
  ];
  switch (definition.type) {
    case SchemaType.object:
      result.writeln('  $name({');
      for (final property in propertyMetadatas) {
        result.writeln(switch (property.type) {
          PropertyType.object =>
            '${property.elementTypeName}? ${property.name},',
          PropertyType.bool => 'bool? ${property.name},',
          PropertyType.string => 'String? ${property.name},',
          PropertyType.list =>
            'List<${property.elementTypeName}>? ${property.name},',
          PropertyType.map =>
            'Map<String, ${property.elementTypeName}>? ${property.name},',
        });
      }
      result.writeln('}) : this.fromJson({');
      for (final property in propertyMetadatas) {
        result.writeln('if (${property.name} != null) '
            "'${property.name}': ${property.name},");
      }
      result.writeln('});');
    case SchemaType.string:
      result.writeln('$name(String string) : this.fromJson(string);');
    default:
      throw UnsupportedError('Unsupported type: ${definition.type}');
  }

  // Generate a getter for every field that looks up in the JSON and "creates"
  // extension types or casts collections as needed. The getters assume the
  // data is present and will throw if it's not.
  for (final property in propertyMetadatas) {
    result.writeln(switch (property.type) {
      PropertyType.object =>
        // TODO(davidmorgan): use the extension type constructor instead of
        // casting.
        '${property.elementTypeName} get ${property.name} => '
            'node[\'${property.name}\'] '
            'as ${property.elementTypeName};',
      PropertyType.bool => 'bool get ${property.name} => '
          'node[\'${property.name}\'] as bool;',
      PropertyType.string => 'String get ${property.name} => '
          'node[\'${property.name}\'] as String;',
      PropertyType.list =>
        'List<${property.elementTypeName}> get ${property.name} => '
            '(node[\'${property.name}\'] as List).cast();',
      PropertyType.map =>
        'Map<String, ${property.elementTypeName}> get ${property.name} => '
            '(node[\'${property.name}\'] as Map).cast();',
    });
  }
  result.writeln('}');
  return result.toString();
}

/// Gets information about an extension type property from [schema].
PropertyMetadata _readPropertyMetadata(String name, JsonSchema schema) {
  // Check for a `$ref` to another extension type defined under `$defs`.
  if (schema.schemaMap!.containsKey(r'$ref')) {
    final ref = schema.schemaMap![r'$ref'] as String;
    if (ref.startsWith(r'#/$defs/')) {
      final schemaName = ref.substring(r'#/$defs/'.length);
      return PropertyMetadata(
          name: name, type: PropertyType.object, elementTypeName: schemaName);
    } else {
      throw UnsupportedError('Unsupported: $name $schema');
    }
  }

  // Otherwise, it's a schema with a type.
  return switch (schema.type) {
    SchemaType.boolean => PropertyMetadata(name: name, type: PropertyType.bool),
    SchemaType.string =>
      PropertyMetadata(name: name, type: PropertyType.string),
    SchemaType.array => PropertyMetadata(
        name: name,
        type: PropertyType.list,
        // `items` should be a type specified with a `$ref`.
        elementTypeName: _readRefName(schema, 'items')),
    SchemaType.object => PropertyMetadata(
        name: name,
        type: PropertyType.map,
        // `additionalProperties` should be a type specified with a `$ref`.
        elementTypeName: _readRefName(schema, 'additionalProperties')),
    _ => throw UnsupportedError('Unsupported schema type: ${schema.type}'),
  };
}

/// Reads the type name of a `$ref` to a `$def`.
String _readRefName(JsonSchema schema, String key) {
  final ref = (schema.schemaMap![key] as Map)[r'$ref'] as String;
  return ref.substring(r'#/$defs/'.length);
}

/// The Dart types used in extension types to model JSON types.
enum PropertyType {
  object,
  bool,
  string,
  list,
  map,
}

/// Metadata about a property in an extension type.
class PropertyMetadata {
  String name;
  PropertyType type;
  String? elementTypeName;

  PropertyMetadata(
      {required this.name, required this.type, this.elementTypeName});
}

void _mergeCode(File target, String code) {
  final outputLines =
      target.existsSync() ? target.readAsLinesSync() : <String>[];
  final updatedLines = code.split('\n');

  final List<List<String>> unmatchedExtensionTypes = [];
  for (final (name, extensionTypeLines)
      in _splitToExtensionTypes(updatedLines)) {
    final maybeRange = _findExtensionType(name, outputLines);
    if (maybeRange == null) {
      print('Will append missing type: $name');
      unmatchedExtensionTypes.add(extensionTypeLines);
    } else {
      print('Updating existing type: $name');
      final (start, middle, end) = maybeRange;

      if (middle == null) {
        outputLines.replaceRange(start, end + 1, extensionTypeLines);
      } else {
        outputLines.replaceRange(
            start,
            middle - 1,
            // Exclude the ending '}'.
            extensionTypeLines.sublist(0, extensionTypeLines.length - 1));
      }
    }
  }
  for (final extensionTypesLines in unmatchedExtensionTypes) {
    outputLines.addAll(extensionTypesLines);
  }

  target.writeAsStringSync(outputLines.join('\n') + '\n');
}

Iterable<(String, List<String>)> _splitToExtensionTypes(
    List<String> lines) sync* {
  final buffer = <String>[];
  String? name;
  for (final line in lines) {
    if (line.startsWith('extension type ')) {
      name = line.substring('extension type '.length);
      name = name.substring(0, name.indexOf('.'));
    }
    if (name != null) buffer.add(line);
    if (line == '}') {
      if (name == null) throw ('Expected an extension type!');
      yield (name, buffer.toList());
      name = null;
      buffer.clear();
    }
  }
}

(int, int?, int)? _findExtensionType(String name, List<String> lines) {
  int? start;
  int? middle;
  for (var i = 0; i != lines.length; ++i) {
    final line = lines[i];
    if (line.startsWith('extension type $name.')) {
      start = i;
    } else if (start != null && line == '  // End of generated members.') {
      middle = i;
    } else if (start != null && line == '}') {
      return (start, middle, i);
    }
  }
  return null;
}
