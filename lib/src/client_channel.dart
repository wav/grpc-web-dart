import 'dart:async';

import 'package:grpc/grpc.dart';

import 'call.dart';
import 'connection.dart';

class WebClientChannel extends ClientChannel {
  WebClientChannel(String host, {int port, ChannelOptions options})
      : super(host, port: port, options: options);

  WebClientConnection _connection;

  bool _isShutdown = false;

  /// Shuts down this channel.
  ///
  /// No further RPCs can be made on this channel. RPCs already in progress will
  /// be allowed to complete.
  @override
  Future<Null> shutdown() async {
    if (_isShutdown) return new Future.value();
    _isShutdown = true;
    await _connection.shutdown();
  }

  /// Terminates this channel.
  ///
  /// RPCs already in progress will be terminated. No further RPCs can be made
  /// on this channel.
  @override
  Future<Null> terminate() async {
    _isShutdown = true;
    await _connection.terminate();
  }

  /// Returns a connection to this [Channel]'s RPC endpoint.
  ///
  /// The connection may be shared between multiple RPCs.
  @override
  Future<ClientConnection> getConnection() async {
    if (_isShutdown) throw new GrpcError.unavailable('Channel shutting down.');
    return _connection ??= new WebClientConnection(host, port, options);
  }

  /// Initiates a new RPC on this connection.
  @override
  ClientCall<Q, R> createCall<Q, R>(
      ClientMethod<Q, R> method, Stream<Q> requests, CallOptions options) {
    final call = new WebClientCall(method, requests, options);
    getConnection().then((connection) {
      if (call.isCancelled) return;
      connection.dispatchCall(call);
    }, onError: call.onConnectionError);
    return call;
  }
}
