## gRPC *web* for dart over HTTP/1.1 for non-web clients.

Why would you use this?

You have a non-browser (`'dart:io'`) client connecting with `HTTP/1.1` and a server that is serving the gRPC-Web protocol (`application/grpc-web+proto`).

For all other clients use https://github.com/grpc/grpc-dart 

> Hint: Flutter web requires the server to serve gRPC-Web

The message is unpacked using `grpcwebstreamparser.js` from [github.com/grpc/grpc-dart](https://github.com/grpc/grpc-web)

Only regular RPC calls have been implemented.

## Sample Usage

```
final channel = useHttp2 == true
      ? new ClientChannel(...)
      : new WebClientChannel(...);

final client = BookServiceClient(channel);

client.getBook(new GetBookRequest()..isbn = new Int64(60929871));
```

## Give it a spin

```
make serve &

make test
```

## TODO

- Streaming
- Create a `HTTP Transport` that fits well with the changes for `grpc-web` support [#109](https://github.com/grpc/grpc-dart/pull/109) in `grpc-dart`.
