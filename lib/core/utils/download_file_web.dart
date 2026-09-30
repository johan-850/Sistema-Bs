import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Descarga [bytes] como [fileName] con la barra de descargas del navegador.
void downloadBytes(List<int> bytes, String fileName, String mimeType) {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final blob = web.Blob([data.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Revocar en el acto puede cortar la descarga en algunos navegadores.
  Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
}
