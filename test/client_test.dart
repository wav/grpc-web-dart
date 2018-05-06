// Copyright (c) 2017, the gRPC project authors. Please see the AUTHORS file
// for details. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';

import 'package:grpc/grpc.dart';
import 'package:test/test.dart';

import 'book_service/book_service.pbgrpc.dart';

import 'package:grpc_web/grpc_web.dart';

import 'package:fixnum/fixnum.dart';

class Client {
  ClientChannel channel;
  BookServiceClient stub;

  Future<Null> main(List<String> args) async {
    channel = new WebClientChannel('127.0.0.1',
        port: 9090,
        options: const ChannelOptions(
            idleTimeout: const Duration(milliseconds: 500),
            credentials: const ChannelCredentials.insecure()));
    stub = new BookServiceClient(channel);
    // Run all of the demos in order.
    await runGetBooks();
    await channel.shutdown();
  }

  Future<Null> runGetBooks() async {
    try {
      final call = stub.getBook(new GetBookRequest()..isbn = new Int64(60929871),
          options: new CallOptions(metadata: {'peer': 'Verner'}));
      call.headers.then((headers) {
        print('Received header metadata: $headers');
      });
      call.trailers.then((trailers) {
        print('Received trailer metadata: $trailers');
      });
      final response = await call;
      print('Echo response: ${response.author}');
    } on GrpcError catch (e) {
      assert(e.code == StatusCode.ok, "$e");
    } catch(e) {
      print(e);
    }

  }
}

void main() {
  test("run books", () => new Client().main([]));
}
