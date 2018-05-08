## gRPC *web* for dart

This is a hack/experiment to get gRPC working over HTTP/1 with [https://github.com/improbable-eng/grpc-web](https://github.com/improbable-eng/grpc-web)

It provides an implementation ClientChannel as suggested [grpc/grpc-dart - issue 43](https://github.com/grpc/grpc-dart/issues/43)

The message is unpacked using `grpcwebstreamparser.js` from [github.com/grpc/grpc-dart](https://github.com/grpc/grpc-web)

Only regular RPC calls have been implemented.

## TODO

- Streaming