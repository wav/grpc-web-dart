import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';
import 'package:grpc_web/src/connection.dart';
import 'package:grpc_web/src/stream_parser.dart';
import 'package:http/http.dart' as http;

class WebClientCall<Q, R> extends ClientCall<Q, R> {
  final ClientMethod<Q, R> _method;
  final Stream<Q> _requests;
  StreamController<R> _responses;

  final _headers = new Completer<Map<String, String>>();
  final _trailers = new Completer<Map<String, String>>();

  WebClientCall(
      ClientMethod<Q, R> method, Stream<Q> requests, CallOptions options)
      : _method = method,
        _requests = requests,
        super(method, requests, options) {
    _responses = new StreamController();
  }

  @override
  void onConnectionReady(ClientConnection connection) {
    if (isCancelled) return;
    _invokeRequest(connection as WebClientConnection);
  }

  Future<Null> _invokeRequest(WebClientConnection c) async {
    final url = Uri.parse("http://${c.host}:${c.port}${path}");
    this._requests.listen((message) async {
      var serialized = _method.requestSerializer(message);
      final headers = <String, String>{}
        ..addAll(options.metadata)
        ..addAll({
          "Content-Type": "application/grpc-web+proto",
          "Accept": "application/grpc-web+proto",
        })
        ..map((k, v) => new MapEntry(ascii.encode(k), ascii.encode(v)));
      final req = new http.Request("POST", url)
        ..headers.addAll(headers)
        ..bodyBytes = _encodeRequest(serialized);
      http.StreamedResponse resp;
      try {
        resp = await req.send().timeout(c.options.idleTimeout);
      } on TimeoutException {
        _responseError(new GrpcError.deadlineExceeded(
            "Request took longer than ${c.options.idleTimeout
                .inMilliseconds}ms"));
        return;
      }
      await _onResponse(resp);
    });
  }

  Future<Null> _onResponse(http.StreamedResponse value) async {
    _headers.complete(value.headers);
    var bytes = await value.stream.toBytes();
    var parser = new GrpcWebStreamParser();
    var messages = parser.parse(bytes);
    for (var m in messages) {
      if (!m.isTrailer) {
        if (_trailers.isCompleted) {
          _responseError(
              new GrpcError.unimplemented('Received data after trailers'));
          return;
        }
        if (!m.isEmpty) {
          var parsed = _method.responseDeserializer(m.message);
          _responses.add(parsed);
        }
      } else if (m.isTrailer) {
        if (_trailers.isCompleted) {
          _responseError(
              new GrpcError.unimplemented('Received multiple trailers'));
          return;
        }
        if (!m.isEmpty) {
          try {
            var metadata = _decodeMetadata(m.message);
            if (metadata.containsKey('grpc-status')) {
              final status = int.parse(metadata['grpc-status']);
              final message = metadata['grpc-message'];
              if (status != 0) {
                _responseError(new GrpcError.custom(status, message));
              }
            }
            _trailers.complete(metadata);
          } catch (e) {
            _responseError(
                new GrpcError.unimplemented('Failed to decode trailers'));
            return;
          } finally {
            if (!_trailers.isCompleted) {
              _trailers.complete(const {});
            }
          }
        } else {
          _responseError(
              new GrpcError.unimplemented('Failed to decode trailers'));
          return;
        }
      }
    }
    _responses.close();
  }

  @override
  Stream<R> get response => _responses.stream;

  @override
  Future<Map<String, String>> get headers => _headers.future;

  @override
  Future<Map<String, String>> get trailers => _trailers.future;

  void _responseError(GrpcError error) {
    _responses.addError(error);
    _responses.close();
  }
}

/**
 * Encode the grpc-web request
 *
 * @private
 * @param {!Uint8Array} serialized The serialized proto payload
 * @return {!Uint8Array} The application/grpc-web padded request
 */
Uint8List _encodeRequest(List<int> serialized) {
  var len = serialized.length;
  var bytesArray = [0, 0, 0, 0];
  var payload = new ByteData(5 + len).buffer;
  for (var i = 3; i >= 0; i--) {
    bytesArray[i] = (len % 256);
    len = (len & 0xFFFFFFFF) >> 8;
  }
  new Uint8List.view(payload, 1, 4).setAll(0, bytesArray);
  new Uint8List.view(payload, 5, serialized.length).setAll(0, serialized);
  return payload.asUint8List();
}

class _CharCode {
  static const int LF = 10;
  static const int CR = 13;
  static const int COLON = 58;
}

Map<String, String> _decodeMetadata(List<int> data) {
  var m = <String, String>{};
  var state = _CharCode.LF;
  var window = <int>[];
  String header;
  for (var c in data) {
    switch (state) {
      case _CharCode.LF:
        switch (c) {
          case _CharCode.COLON:
            header = ascii.decode(window).toLowerCase();
            window = [];
            state = _CharCode.COLON;
            break;
          default:
            window.add(c);
        }
        break;
      case _CharCode.CR:
        switch (c) {
          case _CharCode.LF:
            state = _CharCode.LF;
            break;
          default:
            throw new StateError("invalid header data");
        }
        break;
      case _CharCode.COLON:
        switch (c) {
          case _CharCode.CR:
            m[header] = ascii.decode(window);
            window = [];
            header = null;
            state = _CharCode.CR;
            break;
          case _CharCode.LF:
            throw new StateError("invalid header data");
          default:
            window.add(c);
        }
        break;
    }
  }
  return m;
}
