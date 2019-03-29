import 'package:flutter/material.dart';
import 'package:flutter_book_service/book_service/book_service.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:grpc_web/grpc_web.dart';

const DEFAULT_SERVER = "https://localhost:9090";

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Book Service',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BookList(),
    );
  }
}

class BookList extends StatefulWidget {
  BookList({Key key}) : super(key: key);

  @override
  _BookListState createState() => _BookListState();
}

class _BookListState extends State<BookList> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  var _books = <Book>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text("Books"),
      ),
      body: ListView.builder(
          // first 2 list items are the settings "serverName" and "httpToggle"
          itemBuilder: _itemBuilder,
          itemCount: _books.length + 2),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : _loadBooks,
        tooltip: 'Load Books',
        child: _busy ? CircularProgressIndicator() : Icon(Icons.refresh),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  bool _busy = false;

  void _loadBooks() async {
    if (_serverName.isEmpty)
      setState(() {
        _serverName = DEFAULT_SERVER;
      });
    setState(() {
      _busy = true;
    });
    _scaffoldKey.currentState.hideCurrentSnackBar();
    try {
      final client = _makeBooksClient(_serverName, useHttp2: _useHttp2);
      final stream = await client.queryBooks(new QueryBooksRequest());
      final collected = await stream.toList();
      setState(() {
        _books = collected;
      });
    } catch (e, s) {
      _reportError(_scaffoldKey, e.toString());
    }
    setState(() {
      _busy = false;
    });
  }

  String _serverName = DEFAULT_SERVER;

  Widget get _serverInput => Padding(
        padding: EdgeInsets.all(12.0),
        child: TextField(
          decoration: InputDecoration(
            hintText: "Server name",
          ),
          controller: new TextEditingController(text: _serverName),
          onChanged: (value) => _serverName = value,
        ),
      );

  bool _useHttp2 = false;

  Widget get _http2Toggle => ListTile(
        title: Text("HTTP/2 enabled"),
        trailing: Checkbox(
          value: _useHttp2,
          onChanged: (value) => setState(() {
                _useHttp2 = value;
              }),
        ),
      );

  Widget _itemBuilder(BuildContext context, int index) {
    if (index == 0) {
      return _serverInput;
    }
    if (index == 1) {
      return _http2Toggle;
    }
    final book = _books[index - 2];
    return ListTile(
      title: new Text(book.title),
      subtitle: new Text("ISBN ${book.isbn}, Author ${book.author}"),
    );
  }
}

BookServiceClient _makeBooksClient(String serverName, {bool useHttp2 = false}) {
  final uri = Uri.parse(serverName);
  final options = ChannelOptions(
    credentials: ChannelCredentials.secure(
      onBadCertificate: allowBadCertificates,
    ),
  );
  final channel = useHttp2
      ? new ClientChannel(uri.host, port: uri.port, options: options)
      : new WebClientChannel(uri.host, port: uri.port, options: options);
  return BookServiceClient(channel);
}

void _reportError(GlobalKey<ScaffoldState> key, String error) =>
    key.currentState.showSnackBar(new SnackBar(
      backgroundColor: Colors.red,
      content: new Text(error),
    ));
