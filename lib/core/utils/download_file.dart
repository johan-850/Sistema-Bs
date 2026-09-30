// Descarga de archivos desde el navegador (USB-028). La implementación real
// usa package:web, que no compila en la VM de `flutter test`: por eso la
// importación condicional.
import 'dart:convert';

import 'download_file_stub.dart' if (dart.library.js_interop) 'download_file_web.dart';

export 'download_file_stub.dart' if (dart.library.js_interop) 'download_file_web.dart';
export 'export_file_name.dart';

/// Con BOM: sin él, Excel en Windows abre el UTF-8 como si fuera Latin-1 y
/// rompe las tildes. El importador de productos lo tolera (trim lo quita).
void downloadCsv(String csv, String fileName) => downloadBytes(utf8.encode('﻿$csv'), fileName, 'text/csv');

void downloadPdf(List<int> bytes, String fileName) => downloadBytes(bytes, fileName, 'application/pdf');
