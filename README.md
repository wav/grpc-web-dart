## gRPC *web* for dart over HTTP/1.1

> Recently merged `grpc-web` support [#109](https://github.com/grpc/grpc-dart/pull/109) uses an `XhrTransport` suitable for the browser.
> This project uses `'dart:io'` for a regular `HTTP transport` for non-brower clients.

Although this is a hack/experiment to get gRPC working over HTTP/1 with [https://github.com/improbable-eng/grpc-web](https://github.com/improbable-eng/grpc-web); it has been in use for a while using this setup.

It provides an implementation of ClientChannel as suggested [grpc/grpc-dart - issue 43](https://github.com/grpc/grpc-dart/issues/43)

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
