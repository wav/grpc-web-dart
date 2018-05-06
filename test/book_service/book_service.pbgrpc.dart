///
//  Generated code. Do not modify.
///
// ignore_for_file: non_constant_identifier_names,library_prefixes
library examplecom.library_book_service_pbgrpc;

import 'dart:async';

import 'package:grpc/grpc.dart';

import 'book_service.pb.dart';
export 'book_service.pb.dart';

class BookServiceClient extends Client {
  static final _$getBook = new ClientMethod<GetBookRequest, Book>(
      '/examplecom.library.BookService/GetBook',
      (GetBookRequest value) => value.writeToBuffer(),
      (List<int> value) => new Book.fromBuffer(value));
  static final _$queryBooks = new ClientMethod<QueryBooksRequest, Book>(
      '/examplecom.library.BookService/QueryBooks',
      (QueryBooksRequest value) => value.writeToBuffer(),
      (List<int> value) => new Book.fromBuffer(value));

  BookServiceClient(ClientChannel channel, {CallOptions options})
      : super(channel, options: options);

  ResponseFuture<Book> getBook(GetBookRequest request, {CallOptions options}) {
    final call = $createCall(_$getBook, new Stream.fromIterable([request]),
        options: options);
    return new ResponseFuture(call);
  }

  ResponseStream<Book> queryBooks(QueryBooksRequest request,
      {CallOptions options}) {
    final call = $createCall(_$queryBooks, new Stream.fromIterable([request]),
        options: options);
    return new ResponseStream(call);
  }
}

abstract class BookServiceBase extends Service {
  String get $name => 'examplecom.library.BookService';

  BookServiceBase() {
    $addMethod(new ServiceMethod<GetBookRequest, Book>(
        'GetBook',
        getBook_Pre,
        false,
        false,
        (List<int> value) => new GetBookRequest.fromBuffer(value),
        (Book value) => value.writeToBuffer()));
    $addMethod(new ServiceMethod<QueryBooksRequest, Book>(
        'QueryBooks',
        queryBooks_Pre,
        false,
        true,
        (List<int> value) => new QueryBooksRequest.fromBuffer(value),
        (Book value) => value.writeToBuffer()));
  }

  Future<Book> getBook_Pre(ServiceCall call, Future request) async {
    return getBook(call, await request);
  }

  Stream<Book> queryBooks_Pre(ServiceCall call, Future request) async* {
    yield* queryBooks(call, (await request) as QueryBooksRequest);
  }

  Future<Book> getBook(ServiceCall call, GetBookRequest request);
  Stream<Book> queryBooks(ServiceCall call, QueryBooksRequest request);
}
