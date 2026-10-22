import 'dart:typed_data';

/// Test-meeting archives are made on the presenter page in Chrome; elsewhere there is nothing to save.
void downloadBytes(Uint8List bytes, String fileName) =>
    throw UnsupportedError('downloads are only available in the browser');
