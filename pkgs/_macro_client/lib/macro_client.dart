// Copyright (c) 2024, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:dart_model/dart_model.dart';
import 'package:macro/macro.dart';
import 'package:macro_service/macro_service.dart';

/// Local macro client which runs macros as directed by requests from a remote
/// macro host.
///
/// TODO(davidmorgan): handle shutdown and dispose.
/// TODO(davidmorgan): split to multpile implementations depending on
/// transport used to connect to host.
class MacroClient {
  final Protocol protocol;
  final Iterable<Macro> macros;
  final Socket socket;
  late final RemoteMacroHost _host;
  Completer<Response>? _responseCompleter;

  MacroClient._(this.protocol, this.macros, this.socket) {
    _host = RemoteMacroHost(this);

    // TODO(davidmorgan): negotiation about protocol version goes here.

    // Tell the host which macros are in this bundle.
    for (final macro in macros) {
      DartModelScope('macro').runSync(() => _sendRequest(
          MacroRequest.macroStartedRequest(
              MacroStartedRequest(macroDescription: macro.description),
              id: nextRequestId)));
    }

    protocol.decode(socket).listen(_handleRequest);
  }

  /// Runs [macros] for the host at [endpoint].
  static Future<MacroClient> run({
    // TODO(davidmorgan): this should be negotiated, not just passed in.
    required Protocol protocol,
    required HostEndpoint endpoint,
    required Iterable<Macro> macros,
  }) async {
    final socket = await Socket.connect('localhost', endpoint.port);
    return MacroClient._(protocol, macros, socket);
  }

  void _sendRequest(MacroRequest request) {
    protocol.send(socket.add, request.node);
  }

  void _sendResponse(Response response) {
    protocol.send(socket.add, response.node);
  }

  void _handleRequest(Map<String, Object?> jsonData) async {
    final hostRequest = HostRequest.fromJson(jsonData);
    switch (hostRequest.type) {
      case HostRequestType.augmentRequest:
        await DartModelScope('macro').run(() async {
          final response = Response.augmentResponse(
              await macros.single.augment(_host, hostRequest.asAugmentRequest),
              requestId: hostRequest.id);
          _sendResponse(response);
        });

      default:
      // Ignore unknown request.
      // TODO(davidmorgan): make handling of unknown request types a designed
      // part of the protocol+code, update implementation here and below.
    }
    final response = Response.fromJson(jsonData);
    // TODO(davidmorgan): track requests and responses properly.
    if (_responseCompleter != null) {
      _responseCompleter!.complete(response);
      _responseCompleter = null;
    }
  }
}

/// [Host] that is connected to a remote macro host.
///
/// Wraps `MacroClient` exposing just what should be available to the macro.
///
/// This gets passed into user-written macro code, so fields and methods here
/// can be accessed by the macro code if they are public, even if they are not
/// on `Host`, via dynamic dispatch.
///
/// TODO(language/issues/3951): follow up on security implications.
///
class RemoteMacroHost implements Host {
  final MacroClient _client;

  RemoteMacroHost(this._client);

  @override
  Future<Model> query(Query query) async {
    await DartModelScope('query').run(() async {
      _client._sendRequest(MacroRequest.queryRequest(QueryRequest(query: query),
          id: nextRequestId));
    });
    // TODO(davidmorgan): this is needed because the constructor doesn't wait
    // for responses to `MacroStartedRequest`, so we need to discard the
    // responses. Properly track requests and responses.
    while (true) {
      final nextResponse = await _nextResponse();
      if (nextResponse.type == ResponseType.macroStartedResponse) {
        continue;
      }
      return nextResponse.asQueryResponse.model;
    }
  }

  Future<Response> _nextResponse() async {
    _client._responseCompleter = Completer<Response>();
    return await _client._responseCompleter!.future;
  }
}
