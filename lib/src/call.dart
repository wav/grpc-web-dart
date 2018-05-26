import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';
import 'connection.dart';
import 'stream_parser.dart';
import 'util.dart';

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
    this._requests.listen((message) async {
      try {
        final url = Uri.parse(
            "http${c.options.credentials.isSecure ? "s" : ""}://${c.host}:${c
                .port}$path");
        final serialized = _method.requestSerializer(message);
        final encoded = encodeRequest(serialized);
        var headers = <String, String>{};
        for (var provider in options.metadataProviders) {
          await provider(headers, url.toString());
        }
        headers = headers
          ..addAll(options.metadata)
          ..addAll({
            "Content-Type": "application/grpc-web+proto",
            "Accept": "application/grpc-web+proto",
            "Content-Length": encoded.lengthInBytes.toString(),
          })
          ..map((k, v) => new MapEntry(ascii.encode(k), ascii.encode(v)));

        // disable http2 for this request otherwise the TLS handshake will fail. eg. "bogus greeting" error
        final secCtx =  c.options.credentials.securityContext
          ..setAlpnProtocols(['http/1.1'], false);
        final cli =
            new HttpClient(context: secCtx);
        if (c.options.credentials.onBadCertificate != null) {
          cli.badCertificateCallback = (cert, host, _) =>
              c.options.credentials.onBadCertificate(cert, host);
        }
        print("POST $url");
        final req = await cli.openUrl("POST", url);
        for (var key in headers.keys) {
          print("request header: $key: ${headers[key]}");
          req.headers.add(key, headers[key]);
        }
        req.add(encoded);
        final resp = await req.close().timeout(c.options.idleTimeout);
        await _onResponse(resp, c.options.idleTimeout);
      } on TimeoutException {
        _setTimeoutError(c.options.idleTimeout);
        return;
      } catch (e, s) {
        print("$e $s");
        _responseError(new GrpcError.aborted("$e"));
        return;
      }
    });
  }

  void _setTimeoutError(Duration idleTimeout) {
    _responseError(new GrpcError.deadlineExceeded(
        "Request took longer than ${idleTimeout.inMilliseconds}ms"));
  }

  Future<Uint8List> _readResponse(
      HttpClientResponse response, Duration idleTimeout) async {
    try {
      return new Uint8List.fromList(await response
          .fold(<int>[], (a, b) => a..addAll(b)).timeout(idleTimeout));
    } on TimeoutException {
      _setTimeoutError(idleTimeout);
      return null;
    } catch (e, s) {
      print("$e $s");
      _responseError(new GrpcError.aborted("$e"));
      return null;
    }
  }

  Future<Null> _readHeaders(HttpClientResponse response) async {
    try {
      final headers = <String, String>{};
      response.headers.forEach((k, v) {
        final val = v.join(",");
        print("response header: $k: $val");
        headers[k] = val;
      });
      _headers.complete(headers);
      if (headers.containsKey('grpc-status')) {
        final status = int.parse(headers['grpc-status']);
        final message = headers['grpc-message'];
        if (status != 0) {
          _responseError(new GrpcError.custom(status, message));
          return;
        }
      }
    } catch (e, s) {
      print("$e $s");
      _responseError(new GrpcError.aborted("$e"));
      return;
    }
  }

  void _readTrailer(Message m) {
    if (_trailers.isCompleted) {
      _responseError(new GrpcError.unimplemented('Received multiple trailers'));
      return;
    }
    try {
      var metadata = decodeMetadata(m.message);
      if (metadata.containsKey('grpc-status')) {
        final status = int.parse(metadata['grpc-status']);
        final message = metadata['grpc-message'];
        if (status != 0) {
          _responseError(new GrpcError.custom(status, message));
        }
      }
      _trailers.complete(metadata);
    } catch (e) {
      _responseError(new GrpcError.unimplemented('Failed to decode trailers'));
      return;
    } finally {
      if (!_trailers.isCompleted) {
        _trailers.complete(const {});
      }
    }
  }

  void _readMessage(Message m) {
    if (_trailers.isCompleted) {
      _responseError(
          new GrpcError.unimplemented('Received data after trailers'));
      return;
    }
    final parsed = _method.responseDeserializer(m.message);
    _responses.add(parsed);
    print("$parsed");
  }

  Future<Null> _onResponse(
      HttpClientResponse response, Duration idleTimeout) async {
    await _readHeaders(response);

    var bytes = await _readResponse(response, idleTimeout);
    if (_responses.isClosed) return;

    if (bytes.length == 0) {
      print("grpc_web: no data received, closing");
      _responses.close();
      _trailers.complete(const {});
      return;
    }
    try {
      new GrpcWebStreamParser()
          .parse(bytes)
          .forEach((m) => m.isTrailer ? _readTrailer(m) : _readMessage(m));
    } catch (e, s) {
      print("$e $s");
      _responseError(new GrpcError.aborted("$e"));
    } finally {
      _responses.close();
    }
  }

  @override
  Stream<R> get response => _responses.stream;

  @override
  Future<Map<String, String>> get headers => _headers.future;

  @override
  Future<Map<String, String>> get trailers => _trailers.future;

  void _responseError(GrpcError error) {
    if (!_headers.isCompleted) _headers.completeError(error);
    if (!_responses.isClosed) {
      _responses.addError(error);
      _responses.close();
    }
    if (!_trailers.isCompleted) _trailers.completeError(error);
  }
}