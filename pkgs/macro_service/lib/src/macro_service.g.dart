// This file is generated. To make changes edit schemas/*.schema.json
// then run from the repo root: dart tool/dart_model_generator/bin/main.dart

import 'package:dart_model/src/json_buffer/json_buffer_builder.dart';
import 'package:dart_model/dart_model.dart';

/// A request to a macro to augment some code.
extension type AugmentRequest.fromJson(Map<String, Object?> node)
    implements Object {
  static final TypedMapSchema _schema = TypedMapSchema({
    'phase': Type.uint32,
    'target': Type.stringPointer,
  });
  AugmentRequest({
    int? phase,
    QualifiedName? target,
  }) : this.fromJson(DartModelScope.createMap(
          _schema,
          phase,
          target,
        ));

  /// Which phase to run: 1, 2 or 3.
  int get phase => node['phase'] as int;

  /// The class to augment. TODO(davidmorgan): expand to more types of target
  QualifiedName get target => node['target'] as QualifiedName;
}

/// Macro's response to an [AugmentRequest]: the resulting augmentations.
extension type AugmentResponse.fromJson(Map<String, Object?> node)
    implements Object {
  static final TypedMapSchema _schema = TypedMapSchema({
    'augmentations': Type.closedListPointer,
  });
  AugmentResponse({
    List<Augmentation>? augmentations,
  }) : this.fromJson(DartModelScope.createMap(
          _schema,
          augmentations,
        ));

  /// The augmentations.
  List<Augmentation> get augmentations =>
      (node['augmentations'] as List).cast();
}

/// Request could not be handled.
extension type ErrorResponse.fromJson(Map<String, Object?> node)
    implements Object {
  static final TypedMapSchema _schema = TypedMapSchema({
    'error': Type.stringPointer,
  });
  ErrorResponse({
    String? error,
  }) : this.fromJson(DartModelScope.createMap(
          _schema,
          error,
        ));

  /// The error.
  String get error => node['error'] as String;
}

/// A macro host server endpoint. TODO(davidmorgan): this should be a oneOf supporting different types of connection. TODO(davidmorgan): it's not clear if this belongs in this package! But, where else?
extension type HostEndpoint.fromJson(Map<String, Object?> node)
    implements Object {
  static final TypedMapSchema _schema = TypedMapSchema({
    'port': Type.uint32,
  });
  HostEndpoint({
    int? port,
  }) : this.fromJson(DartModelScope.createMap(
          _schema,
          port,
        ));

  /// TCP port to connect to.
  int get port => node['port'] as int;
}

enum HostRequestType {
  // Private so switches must have a default. See `isKnown`.
  _unknown,
  augmentRequest;

  bool get isKnown => this != _unknown;
}

extension type HostRequest.fromJson(Map<String, Object?> node)
    implements Object {
  static HostRequest augmentRequest(
    AugmentRequest augmentRequest, {
    required int id,
  }) =>
      HostRequest.fromJson({
        'type': 'AugmentRequest',
        'value': augmentRequest,
        'id': id,
      });
  HostRequestType get type {
    switch (node['type'] as String) {
      case 'AugmentRequest':
        return HostRequestType.augmentRequest;
      default:
        return HostRequestType._unknown;
    }
  }

  AugmentRequest get asAugmentRequest {
    if (node['type'] != 'AugmentRequest') {
      throw StateError('Not a AugmentRequest.');
    }
    return AugmentRequest.fromJson(node['value'] as Map<String, Object?>);
  }

  /// The id of this request, must be returned in responses.
  int get id => node['id'] as int;
}

/// Information about a macro that the macro provides to the host.
extension type MacroDescription.fromJson(Map<String, Object?> node)
    implements Object {
  static final TypedMapSchema _schema = TypedMapSchema({
    'runsInPhases': Type.closedListPointer,
  });
  MacroDescription({
    List<int>? runsInPhases,
  }) : this.fromJson(DartModelScope.createMap(
          _schema,
          runsInPhases,
        ));

  /// Phases that the macro runs in: 1, 2 and/or 3.
  List<int> get runsInPhases => (node['runsInPhases'] as List).cast();
}

/// Informs the host that a macro has started.
extension type MacroStartedRequest.fromJson(Map<String, Object?> node)
    implements Object {
  static final TypedMapSchema _schema = TypedMapSchema({
    'macroDescription': Type.typedMapPointer,
  });
  MacroStartedRequest({
    MacroDescription? macroDescription,
  }) : this.fromJson(DartModelScope.createMap(
          _schema,
          macroDescription,
        ));
  MacroDescription get macroDescription =>
      node['macroDescription'] as MacroDescription;
}

/// Host's response to a [MacroStartedRequest].
extension type MacroStartedResponse.fromJson(Map<String, Object?> node)
    implements Object {
  static final TypedMapSchema _schema = TypedMapSchema({});
  MacroStartedResponse()
      : this.fromJson(DartModelScope.createMap(
          _schema,
        ));
}

enum MacroRequestType {
  // Private so switches must have a default. See `isKnown`.
  _unknown,
  macroStartedRequest,
  queryRequest;

  bool get isKnown => this != _unknown;
}

extension type MacroRequest.fromJson(Map<String, Object?> node)
    implements Object {
  static MacroRequest macroStartedRequest(
    MacroStartedRequest macroStartedRequest, {
    required int id,
  }) =>
      MacroRequest.fromJson({
        'type': 'MacroStartedRequest',
        'value': macroStartedRequest,
        'id': id,
      });
  static MacroRequest queryRequest(
    QueryRequest queryRequest, {
    required int id,
  }) =>
      MacroRequest.fromJson({
        'type': 'QueryRequest',
        'value': queryRequest,
        'id': id,
      });
  MacroRequestType get type {
    switch (node['type'] as String) {
      case 'MacroStartedRequest':
        return MacroRequestType.macroStartedRequest;
      case 'QueryRequest':
        return MacroRequestType.queryRequest;
      default:
        return MacroRequestType._unknown;
    }
  }

  MacroStartedRequest get asMacroStartedRequest {
    if (node['type'] != 'MacroStartedRequest') {
      throw StateError('Not a MacroStartedRequest.');
    }
    return MacroStartedRequest.fromJson(node['value'] as Map<String, Object?>);
  }

  QueryRequest get asQueryRequest {
    if (node['type'] != 'QueryRequest') {
      throw StateError('Not a QueryRequest.');
    }
    return QueryRequest.fromJson(node['value'] as Map<String, Object?>);
  }

  /// The id of this request, must be returned in responses.
  int get id => node['id'] as int;
}

/// The macro to host protocol version and encoding. TODO(davidmorgan): add the version.
extension type Protocol.fromJson(Map<String, Object?> node) implements Object {
  static final TypedMapSchema _schema = TypedMapSchema({
    'encoding': Type.stringPointer,
  });
  Protocol({
    String? encoding,
  }) : this.fromJson(DartModelScope.createMap(
          _schema,
          encoding,
        ));

  /// The wire format: json or binary. TODO(davidmorgan): use an enum?
  String get encoding => node['encoding'] as String;
}

/// Macro's query about the code it should augment.
extension type QueryRequest.fromJson(Map<String, Object?> node)
    implements Object {
  static final TypedMapSchema _schema = TypedMapSchema({
    'query': Type.stringPointer,
  });
  QueryRequest({
    Query? query,
  }) : this.fromJson(DartModelScope.createMap(
          _schema,
          query,
        ));
  Query get query => node['query'] as Query;
}

/// Host's response to a [QueryRequest].
extension type QueryResponse.fromJson(Map<String, Object?> node)
    implements Object {
  static final TypedMapSchema _schema = TypedMapSchema({
    'model': Type.stringPointer,
  });
  QueryResponse({
    Model? model,
  }) : this.fromJson(DartModelScope.createMap(
          _schema,
          model,
        ));
  Model get model => node['model'] as Model;
}

enum ResponseType {
  // Private so switches must have a default. See `isKnown`.
  _unknown,
  augmentResponse,
  errorResponse,
  macroStartedResponse,
  queryResponse;

  bool get isKnown => this != _unknown;
}

extension type Response.fromJson(Map<String, Object?> node) implements Object {
  static Response augmentResponse(
    AugmentResponse augmentResponse, {
    required int requestId,
  }) =>
      Response.fromJson({
        'type': 'AugmentResponse',
        'value': augmentResponse,
        'requestId': requestId,
      });
  static Response errorResponse(
    ErrorResponse errorResponse, {
    required int requestId,
  }) =>
      Response.fromJson({
        'type': 'ErrorResponse',
        'value': errorResponse,
        'requestId': requestId,
      });
  static Response macroStartedResponse(
    MacroStartedResponse macroStartedResponse, {
    required int requestId,
  }) =>
      Response.fromJson({
        'type': 'MacroStartedResponse',
        'value': macroStartedResponse,
        'requestId': requestId,
      });
  static Response queryResponse(
    QueryResponse queryResponse, {
    required int requestId,
  }) =>
      Response.fromJson({
        'type': 'QueryResponse',
        'value': queryResponse,
        'requestId': requestId,
      });
  ResponseType get type {
    switch (node['type'] as String) {
      case 'AugmentResponse':
        return ResponseType.augmentResponse;
      case 'ErrorResponse':
        return ResponseType.errorResponse;
      case 'MacroStartedResponse':
        return ResponseType.macroStartedResponse;
      case 'QueryResponse':
        return ResponseType.queryResponse;
      default:
        return ResponseType._unknown;
    }
  }

  AugmentResponse get asAugmentResponse {
    if (node['type'] != 'AugmentResponse') {
      throw StateError('Not a AugmentResponse.');
    }
    return AugmentResponse.fromJson(node['value'] as Map<String, Object?>);
  }

  ErrorResponse get asErrorResponse {
    if (node['type'] != 'ErrorResponse') {
      throw StateError('Not a ErrorResponse.');
    }
    return ErrorResponse.fromJson(node['value'] as Map<String, Object?>);
  }

  MacroStartedResponse get asMacroStartedResponse {
    if (node['type'] != 'MacroStartedResponse') {
      throw StateError('Not a MacroStartedResponse.');
    }
    return MacroStartedResponse.fromJson(node['value'] as Map<String, Object?>);
  }

  QueryResponse get asQueryResponse {
    if (node['type'] != 'QueryResponse') {
      throw StateError('Not a QueryResponse.');
    }
    return QueryResponse.fromJson(node['value'] as Map<String, Object?>);
  }

  /// The id of the request this is responding to.
  int get requestId => node['requestId'] as int;
}
