import 'dart:typed_data';

import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart' as platform;

/// Saves [bytes] as a file on this device (the browser's download). Nothing is uploaded.
void downloadBytes(Uint8List bytes, String fileName) => platform.downloadBytes(bytes, fileName);
