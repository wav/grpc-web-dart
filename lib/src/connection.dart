import 'package:grpc/grpc.dart';
import 'call.dart';

class WebClientConnection extends ClientConnection {
  WebClientConnection(String host, int port, ChannelOptions options)
      : super(host, port, options);

  @override
  void dispatchCall(ClientCall call) {
    (call as WebClientCall).onConnectionReady(this);
  }
}