import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:grpc/grpc.dart';
import 'package:grpc/src/client/connection.dart';
import 'package:grpc/src/client/transport/transport.dart';
import 'package:grpc/src/client/transport/web_streams.dart';
import 'package:grpc/src/shared/message.dart';

class HttpClientConnection extends ClientConnection {
  final String host;
  final int port;
  final ChannelOptions options;

  final Set<HttpTransportStream> _requests = Set<HttpTransportStream>();

  HttpClientConnection(this.host, this.port, {this.options})
      : assert(host?.isNotEmpty == true),
        assert(port == null || port > 0);

  String get authority =>
      "${this.host}:${this.port ?? (options.credentials.isSecure ? 443 : 80)}";

  String get scheme => "http${options.credentials.isSecure ? "s" : ""}";

  void _initializeRequest(HttpClientRequest request,
      Map<String, String> metadata) {
    for (final header in metadata.keys) {
      request.headers.add(header, metadata[header]);
    }
    request.headers.add('Content-Type', 'application/grpc-web+proto');
    request.headers.add('X-User-Agent', 'grpc-web-dart/0.1');
    request.headers.add('X-Grpc-Web', '1');
  }

//  @visibleForTesting
  HttpClient createHttpClient() {
    // disable http2 for this request otherwise the TLS handshake will fail. eg. "bogus greeting" error
    final secCtx = options.credentials.securityContext
      ..setAlpnProtocols(['http/1.1'], false);
    final cli = new HttpClient(context: secCtx);
    if (options.credentials.onBadCertificate != null) {
      cli.badCertificateCallback =
          (cert, host, _) => options.credentials.onBadCertificate(cert, host);
    }
    cli.idleTimeout = options.idleTimeout;
    return cli;
  }

  @override
  GrpcTransportStream makeRequest(String path, Duration timeout,
      Map<String, String> metadata, ErrorHandler onError) {
    final HttpClient cli = createHttpClient();

    final url = Uri.parse(
        "$scheme://${host}:${port}$path");

    final request = cli.openUrl('POST', url).then((r) {
      _initializeRequest(r, metadata);
      return r;
    });
    final transportStream =
    HttpTransportStream(request, onError: onError, onDone: _removeStream);
    _requests.add(transportStream);
    return transportStream;
  }

  void _removeStream(HttpTransportStream stream) {
    _requests.remove(stream);
  }

  @override
  Future<void> terminate() async {
    for (HttpTransportStream request in _requests) {
      request.terminate();
    }
  }

  @override
  void dispatchCall(ClientCall call) {
    call.onConnectionReady(this);
  }

  @override
  Future<void> shutdown() async {}
}

class HttpTransportStream implements GrpcTransportStream {
  final ErrorHandler _onError;
  final Function(HttpTransportStream stream) _onDone;
  final StreamController<ByteBuffer> _incomingProcessor = StreamController();
  final StreamController<GrpcMessage> _incomingMessages = StreamController();
  final StreamController<List<int>> _outgoingMessages = StreamController();

  final Future<HttpClientRequest> _openingRequest;
  HttpClientRequest _request;
  Completer<bool> _firstMessageReceived = Completer();

  @override
  Stream<GrpcMessage> get incomingMessages => _incomingMessages.stream;

  @override
  StreamSink<List<int>> get outgoingMessages => _outgoingMessages.sink;

  HttpTransportStream(this._openingRequest, {onError, onDone})
      : _onError = onError,
        _onDone = onDone {
    _incomingProcessor.stream
        .transform(GrpcWebDecoder())
        .transform(grpcDecompressor())
        .listen(_incomingMessages.add,
        onError: _onError, onDone: _incomingMessages.close);

    _runRequest();
  }

  Future<void> _runRequest() async {
    _request = await _openingRequest;

    if (_incomingMessages.isClosed) {
      return;
    }

    await _request.addStream(await _outgoingMessages.stream.map(frame));

    if (_incomingMessages.isClosed) {
      return;
    }

    final response = await _request.close();

    if (!_onHeadersReceived(response)) {
    return;
    }

    await response
        .map((l) => Uint8List.fromList(l).buffer)
        .pipe(
    _incomingProcessor
    );
  }

  bool _onHeadersReceived(HttpClientResponse response) {
    final contentType = response.headers.contentType.mimeType;
    if (response.statusCode != 200) {
      _onError(GrpcError.unavailable(
          'HttpConnection status ${response.statusCode}'));
      return false;
    }
    if (contentType == null) {
      _onError(GrpcError.unavailable('HttpConnection missing Content-Type'));
      return false;
    }
    if (!contentType.startsWith('application/grpc')) {
      _onError(GrpcError.unavailable(
          'HttpConnection bad Content-Type $contentType'));
      return false;
    }

    final headers = <String, String>{};
    response.headers.forEach((k, v) {
      final val = v.join(",");
      headers[k] = val;
    });

    // Force a metadata message with headers.
    _incomingMessages.add(GrpcMetadata(headers));
    return true;
  }

  _close() {
    if (!_firstMessageReceived.isCompleted) {
      _firstMessageReceived.complete(false);
    }
    _incomingProcessor.close();
    _outgoingMessages.close();
    _onDone(this);
  }

  @override
  Future<void> terminate() async {
    _close();
    if (_request != null) {
      await _request.close();
    }
  }
}
