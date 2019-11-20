import 'package:conquest_mobile/api/grpc_web/src/connection.dart';
import 'package:grpc/grpc.dart';
import 'package:grpc/src/client/connection.dart';

class HttpClientChannel extends ClientChannel {
  final String host;
  final int port;
  final ChannelOptions options;

  HttpClientChannel(this.host, {this.port, this.options})
      : assert(host?.isNotEmpty == true),
        super(host, port: port, options: options);

  @override
  ClientConnection createConnection() {
    return HttpClientConnection(this.host, this.port, options: this.options);
  }
}
