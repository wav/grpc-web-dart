## gRPC *web* for dart over HTTP/1.1 for non-web clients.

Why would you use this?

You have a non-browser (`'dart:io'`) client connecting with `HTTP/1.1` and a server that is serving the gRPC-Web protocol (`application/grpc-web+proto`).

For all other clients use https://github.com/grpc/grpc-dart 

> Hint: Flutter web requires the server to serve gRPC-Web

Only regular RPC calls have been implemented.

## Sample Usage

```
final channel = useHttp2 == true
      ? new ClientChannel(...)
      : new HttpClientChannel(...);

final client = BookServiceClient(channel);

client.getBook(new GetBookRequest()..isbn = new Int64(60929871));
```

## Give it a spin

```
make serve &

make test
```
