import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';

import 'connection.dart';
import 'stream_parser.dart';
import 'util.dart';

typedef void _CancelCallback();

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

  final String _http1contentType = "application/grpc-web+proto";

  // TODO the API that returns the wrong content type even though the client accepts application/grpc-web+proto
  final String _http2contentType = "application/grpc+proto";

  final List<_CancelCallback> _cancelCallbacks = [];

  Future<Null> _invokeRequest(WebClientConnection c) async {
    this._requests.listen((message) async {
      try {
        final url = Uri.parse(
            "http${c.options.credentials.isSecure ? "s" : ""}://${c.host}:${c.port}$path");
        final serialized = _method.requestSerializer(message);
        final encoded = encodeRequest(serialized);
        var headers = <String, String>{};
        for (var provider in options.metadataProviders) {
          await provider(headers, url.toString());
        }
        headers = headers
          ..addAll(options.metadata)
          ..addAll({
            "Content-Type": _http1contentType,
            "Accept": _http1contentType,
            "Content-Length": encoded.lengthInBytes.toString(),
          })
          ..map((k, v) => new MapEntry(ascii.encode(k), ascii.encode(v)));

        // disable http2 for this request otherwise the TLS handshake will fail. eg. "bogus greeting" error
        final secCtx = c.options.credentials.securityContext
          ..setAlpnProtocols(['http/1.1'], false);
        final cli = new HttpClient(context: secCtx);
        if (c.options.credentials.onBadCertificate != null) {
          cli.badCertificateCallback = (cert, host, _) =>
              c.options.credentials.onBadCertificate(cert, host);
        }
        cli.idleTimeout = c.options.idleTimeout;
//        print("POST $url");
        final openReq = cli.openUrl("POST", url);
        final req = await openReq;
        if (_cancelled) {
          req.close();
          return;
        }
        var reqClosed = false;
        final closeReq = () {
          if (reqClosed) return;
          req.close();
        };
        _cancelCallbacks.add(closeReq);
        for (var key in headers.keys) {
//          print("request header: $key: ${headers[key]}");
          req.headers.add(key, headers[key]);
        }
        req.add(encoded);
        final resp = await req.close().timeout(c.options.idleTimeout);
        reqClosed = true;
        if (resp.statusCode == 408) {
          _setTimeoutError(c.options.idleTimeout);
          return;
        }
        await _onResponse(req.uri, resp, c.options.idleTimeout);
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

  Future<bool> _readHeaders(HttpClientResponse response) async {
    try {
      final headers = <String, String>{};
      response.headers.forEach((k, v) {
        final val = v.join(",");
//        print("response header: $k: $val");
        headers[k] = val;
      });
      _headers.complete(headers);
      if (headers.containsKey('grpc-status')) {
        final status = int.parse(headers['grpc-status']);
        final message = headers['grpc-message'];
        if (status != 0) {
          _responseError(new GrpcError.custom(status, message));
          return false;
        }
      }
      return true;
    } catch (e, s) {
      print("$e $s");
      _responseError(new GrpcError.aborted("$e"));
      return false;
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
//    print("$parsed");
  }

  bool isGrpcContentType(String contentType) =>
      (contentType ?? "").startsWith(_http1contentType) ||
      (contentType ?? "").startsWith(_http2contentType);

  Future<Null> _onResponse(
    Uri uri,
    HttpClientResponse response,
    Duration idleTimeout,
  ) async {
    if (!await _readHeaders(response)) {
      return;
    }

    final contentType = response.headers.contentType?.mimeType;
    if (!isGrpcContentType(contentType)) {
      _responseError(new GrpcError.unknown(
          "Failed to decode response expected Content-Type: ${_http1contentType}, got ${contentType}. endpoint: ${uri.toString()}"));
      return;
    }

    var bytes = await _readResponse(response, idleTimeout);
    if (_responses.isClosed) return;

    if (bytes.length == 0) {
      print("grpc_web: no data received, closing");
      _responses.close();
      _trailers.complete(const {});
      return;
    }
    try {
      final messages = new GrpcWebStreamParser().parse(bytes);
      if (messages != null) {
        messages
            .forEach((m) => m.isTrailer ? _readTrailer(m) : _readMessage(m));
      } else {
        _responseError(new GrpcError.unknown("no data was returned"));
      }
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

  bool _cancelled = false;

  @override
  Future<Null> cancel() async {
    if (_cancelled) return;

    if (!_headers.isCompleted) _headers.complete();
    if (!_trailers.isCompleted) _trailers.complete();
    if (!_responses.isClosed) _responses.close();
    for (var f in _cancelCallbacks) {
      await f();
    }
    await super.cancel();
  }
}
