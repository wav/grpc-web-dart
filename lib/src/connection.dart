import 'package:grpc/grpc.dart';

class WebClientConnection extends ClientConnection {
  WebClientConnection(String host, int port, ChannelOptions options)
      : super(host, port, options);

  @override
  void dispatchCall(ClientCall call) {
    call.onConnectionReady(this);
  }
}