import 'dart:typed_data';

/**
 *
 * Copyright 2018 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

/**
 * The default grpc-web stream parser.
 */
class GrpcWebStreamParser {
  /**
   * @fileoverview The default grpc-web stream parser
   *
   * The default grpc-web parser decodes the input stream (binary) under the
   * following rules:
   *
   * 1. The wire format looks like:
   *
   *    0x00 <data> 0x80 <trailer>
   *
   *    For details of grpc-web wire format see
   *    https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-WEB.md
   *
   * 2. Messages will be delivered once each frame is completed. Partial stream
   *    segments are accepted.
   *
   * 3. Example:
   *
   * Incoming data: 0x00 <message1> 0x00 <message2> 0x80 <trailers>
   *
   * Result: [ { 0x00 : <message1 }, { 0x00 : <message2> }, { 0x80 : trailers } ]
   */
  /**
   * The current error message, if any.
   */
  String _errorMessage;

  String get errorMessage => _errorMessage;

  /**
   * The currently buffered result (parsed messages).
   */
  List<Message> _result = [];

  /**
   * The current position in the streamed data.
   */
  int _streamPos = 0;

  _ParserState _state = _ParserState.INIT;

  /**
   * The current frame byte being parsed
   */
  int _frame = 0;

  /**
   * The length of the proto message being parsed.
   * */
  int _length = 0;

  /**
   * Count of processed length bytes.
   */
  int _countLengthBytes = 0;

  /**
   * Raw bytes of the current message.
   */
  Uint8List _messageBuffer = null;

  /**
   * Count of processed message bytes.
   */
  int _countMessageBytes = 0;

  GrpcWebStreamParser();

  bool get isInputInvalid => _state == _ParserState.INVALID;

  /**
   * @param inputBytes The current input buffer
   * @param pos The position in the current input that triggers the error
   * @param errorMsg Additional error message
   * @throws Throws an error indicating where the stream is broken
   * @private
   */
  void _setError(Uint8List inputBytes, int pos, String errorMsg) {
    _state = _ParserState.INVALID;
    _errorMessage =
        "The stream is broken @$_streamPos/$pos. Error: $errorMsg. With input:\n $inputBytes";
    throw new StateError(_errorMessage);
  }

  List<Message> parse(Uint8List inputBytes) {
    var pos = 0;

    void processFrameByte(int b) {
      if ((b & FrameType.DATA) == FrameType.DATA) {
        _frame = b;
      } else if ((b & FrameType.TRAILER) == FrameType.TRAILER) {
        _frame = b;
      } else {
        _setError(inputBytes, pos, "invalid frame byte");
      }
      _state = _ParserState.LENGTH;
      _length = 0;
      _countLengthBytes = 0;
    }

    void processLengthByte(int b) {
      _countLengthBytes++;
//      _length = (_length.toUnsigned(32) << 8) + b;
      _length = (_length & 0x0000000000 << 8) + b;

      if (_countLengthBytes == 4) {
        // no more length byte
        _state = _ParserState.MESSAGE;
        _countMessageBytes = 0;
        _messageBuffer = new Uint8List(_length);

        if (_length == 0) {
          _finishMessage();
        }
      }
    }

    void processMessageByte(int b) {
      _messageBuffer[_countMessageBytes++] = b;
      if (_countMessageBytes == _length) {
        _finishMessage();
      }
    }

    while (pos < inputBytes.length) {
      switch (_state) {
        case _ParserState.INVALID:
          _setError(inputBytes, pos, "stream already broken");
          break;
        case _ParserState.INIT:
          processFrameByte(inputBytes[pos]);
          break;
        case _ParserState.LENGTH:
          processLengthByte(inputBytes[pos]);
          break;
        case _ParserState.MESSAGE:
          processMessageByte(inputBytes[pos]);
          break;
        default:
          throw new StateError("unexpected parser state: ${_state}");
      }

      _streamPos++;
      pos++;
    }

    var msgs = _result;
    _result = [];
    return msgs.length > 0 ? msgs : null;
  }

  void _finishMessage() {
    _result.add(new Message(_frame, _messageBuffer));
    _state = _ParserState.INIT;
  }
}

class Message {
  final int _frameType;
  final List<int> message;

  Message(this._frameType, this.message);

  @override
  String toString() {
    return "Message($_frameType, ${message?.length ?? 0})";
  }

  bool get isTrailer => _frameType % 256 != 0;

  bool get isEmpty => (message?.length ?? 0) == 0;
}

class FrameType {
  static const DATA = 0x00;
  static const TRAILER = 0x80;
}

enum _ParserState {
  INIT, // expecting the next frame byte
  LENGTH, // expecting 4 bytes of length
  MESSAGE, // expecting more message bytes
  INVALID,
}
