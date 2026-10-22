import 'dart:js_interop';
import 'dart:typed_data';

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, _BlobOptions options);
}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}

@JS('URL.createObjectURL')
external String _createObjectUrl(_Blob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);

@JS('document.createElement')
external _Anchor _createElement(String tag);

extension type _Anchor._(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
}

void downloadBytes(Uint8List bytes, String fileName) {
  final url = _createObjectUrl(_Blob([bytes.toJS].toJS, _BlobOptions(type: 'application/zip')));
  _createElement('a')
    ..href = url
    ..download = fileName
    ..click();
  _revokeObjectUrl(url);
}
