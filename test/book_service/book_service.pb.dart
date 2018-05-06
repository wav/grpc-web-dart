///
//  Generated code. Do not modify.
///
// ignore_for_file: non_constant_identifier_names,library_prefixes
library examplecom.library_book_service;

// ignore: UNUSED_SHOWN_NAME
import 'dart:core' show int, bool, double, String, List, override;

import 'package:fixnum/fixnum.dart';
import 'package:protobuf/protobuf.dart';

class Book extends GeneratedMessage {
  static final BuilderInfo _i = new BuilderInfo('Book')
    ..aInt64(1, 'isbn')
    ..aOS(2, 'title')
    ..aOS(3, 'author')
    ..hasRequiredFields = false
  ;

  Book() : super();
  Book.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  Book.fromJson(String i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  Book clone() => new Book()..mergeFromMessage(this);
  BuilderInfo get info_ => _i;
  static Book create() => new Book();
  static PbList<Book> createRepeated() => new PbList<Book>();
  static Book getDefault() {
    if (_defaultInstance == null) _defaultInstance = new _ReadonlyBook();
    return _defaultInstance;
  }
  static Book _defaultInstance;
  static void $checkItem(Book v) {
    if (v is! Book) checkItemFailed(v, 'Book');
  }

  Int64 get isbn => $_getI64(0);
  set isbn(Int64 v) { $_setInt64(0, v); }
  bool hasIsbn() => $_has(0);
  void clearIsbn() => clearField(1);

  String get title => $_getS(1, '');
  set title(String v) { $_setString(1, v); }
  bool hasTitle() => $_has(1);
  void clearTitle() => clearField(2);

  String get author => $_getS(2, '');
  set author(String v) { $_setString(2, v); }
  bool hasAuthor() => $_has(2);
  void clearAuthor() => clearField(3);
}

class _ReadonlyBook extends Book with ReadonlyMessageMixin {}

class GetBookRequest extends GeneratedMessage {
  static final BuilderInfo _i = new BuilderInfo('GetBookRequest')
    ..aInt64(1, 'isbn')
    ..hasRequiredFields = false
  ;

  GetBookRequest() : super();
  GetBookRequest.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  GetBookRequest.fromJson(String i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  GetBookRequest clone() => new GetBookRequest()..mergeFromMessage(this);
  BuilderInfo get info_ => _i;
  static GetBookRequest create() => new GetBookRequest();
  static PbList<GetBookRequest> createRepeated() => new PbList<GetBookRequest>();
  static GetBookRequest getDefault() {
    if (_defaultInstance == null) _defaultInstance = new _ReadonlyGetBookRequest();
    return _defaultInstance;
  }
  static GetBookRequest _defaultInstance;
  static void $checkItem(GetBookRequest v) {
    if (v is! GetBookRequest) checkItemFailed(v, 'GetBookRequest');
  }

  Int64 get isbn => $_getI64(0);
  set isbn(Int64 v) { $_setInt64(0, v); }
  bool hasIsbn() => $_has(0);
  void clearIsbn() => clearField(1);
}

class _ReadonlyGetBookRequest extends GetBookRequest with ReadonlyMessageMixin {}

class QueryBooksRequest extends GeneratedMessage {
  static final BuilderInfo _i = new BuilderInfo('QueryBooksRequest')
    ..aOS(1, 'authorPrefix')
    ..hasRequiredFields = false
  ;

  QueryBooksRequest() : super();
  QueryBooksRequest.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromBuffer(i, r);
  QueryBooksRequest.fromJson(String i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super.fromJson(i, r);
  QueryBooksRequest clone() => new QueryBooksRequest()..mergeFromMessage(this);
  BuilderInfo get info_ => _i;
  static QueryBooksRequest create() => new QueryBooksRequest();
  static PbList<QueryBooksRequest> createRepeated() => new PbList<QueryBooksRequest>();
  static QueryBooksRequest getDefault() {
    if (_defaultInstance == null) _defaultInstance = new _ReadonlyQueryBooksRequest();
    return _defaultInstance;
  }
  static QueryBooksRequest _defaultInstance;
  static void $checkItem(QueryBooksRequest v) {
    if (v is! QueryBooksRequest) checkItemFailed(v, 'QueryBooksRequest');
  }

  String get authorPrefix => $_getS(0, '');
  set authorPrefix(String v) { $_setString(0, v); }
  bool hasAuthorPrefix() => $_has(0);
  void clearAuthorPrefix() => clearField(1);
}

class _ReadonlyQueryBooksRequest extends QueryBooksRequest with ReadonlyMessageMixin {}

