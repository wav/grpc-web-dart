
import 'dart:convert';
import 'dart:typed_data';

/**
 * Encode the grpc-web request
 *
 * @private
 * @param {!Uint8Array} serialized The serialized proto payload
 * @return {!Uint8Array} The application/grpc-web padded request
 */
Uint8List encodeRequest(List<int> serialized) {
  var len = serialized.length;
  var bytesArray = [0, 0, 0, 0];
  var payload = new ByteData(5 + len).buffer;
  for (var i = 3; i >= 0; i--) {
    bytesArray[i] = (len % 256);
    len = (len & 0xFFFFFFFF) >> 8;
  }
  new Uint8List.view(payload, 1, 4).setAll(0, bytesArray);
  new Uint8List.view(payload, 5, serialized.length).setAll(0, serialized);
  return payload.asUint8List();
}

class _CharCode {
  static const int LF = 10;
  static const int CR = 13;
  static const int COLON = 58;
}

Map<String, String> decodeMetadata(List<int> data) {
  var m = <String, String>{};
  var state = _CharCode.LF;
  var window = <int>[];
  String header;
  for (var c in data) {
    switch (state) {
      case _CharCode.LF:
        switch (c) {
          case _CharCode.COLON:
            header = ascii.decode(window).toLowerCase();
            window = [];
            state = _CharCode.COLON;
            break;
          default:
            window.add(c);
        }
        break;
      case _CharCode.CR:
        switch (c) {
          case _CharCode.LF:
            state = _CharCode.LF;
            break;
          default:
            throw new StateError("invalid header data");
        }
        break;
      case _CharCode.COLON:
        switch (c) {
          case _CharCode.CR:
            m[header] = ascii.decode(window);
            window = [];
            header = null;
            state = _CharCode.CR;
            break;
          case _CharCode.LF:
            throw new StateError("invalid header data");
          default:
            window.add(c);
        }
        break;
    }
  }
  return m;
}
