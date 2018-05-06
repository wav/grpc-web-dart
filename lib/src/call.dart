import 'dart:async';
import 'dart:convert';

import 'package:grpc/grpc.dart';
import 'package:grpc_web/src/connection.dart';
import 'package:http/http.dart' as http;

class WebClientCall<Q, R> extends ClientCall<Q, R> {
  final ClientMethod<Q, R> _method;
  final Stream<Q> _requests;
  StreamController<R> _responses;

  WebClientCall(
      ClientMethod<Q, R> method, Stream<Q> requests, CallOptions options)
      : _method = method,
        _requests = requests,
        super(method, requests, options) {
//    _responses = new StreamController(onListen: _onResponseListen);
  }

  @override
  void onConnectionReady(ClientConnection connection) {
    if (this.isCancelled) return;

    var c = connection as WebClientConnection;
    var url = "http://${c.host}:${c.port}${this.path}";

        () async {
      this._requests.listen((message) async {
        var reqBody = this._method.requestSerializer(message);
        var headers = <String, String>{};
        final metadata = new Map.from(options.metadata);
        ClientConnection
            .createCallHeaders(false, "", path, options.timeout, metadata)
            .forEach((h) {
          if (h.name != "content-type") {
            var k = ASCII.decode(h.name);
            if (k.startsWith(":")) {
              k = k.substring(1);
            }
            var v = ASCII.decode(h.value);
            headers.putIfAbsent(k, () => v);
          }
        });
        headers.addAll({
          "Content-Type": "application/grpc-web+proto",
          "Accept": "application/grpc-web-text",
          "Content-Length": reqBody.length.toString(),
        });
        var cli = new http.Client();
        var req = cli.post(url, headers: headers, body: reqBody);
        dynamic resp;
        try {
          await req.timeout(connection.options.idleTimeout);
        } on TimeoutException {
          throw new GrpcError.deadlineExceeded(
              "Request took longer than ${connection.options.idleTimeout
                  .inMilliseconds}ms");
        }

        print("responded");
        cli.close();
        print(resp.statusCode);
        resp.headers.forEach((h, v) {
          print("$h: $v");
        });

        print(resp.contentLength);
        var respBody =
        this._method.responseDeserializer(base64Decode(resp.body));
        print(respBody.toString());
      });
    }();
  }
}
