import 'dart:typed_data';

/// On non-web platforms, direct blob download is not supported.
/// Use Printing.sharePdf instead (called separately on mobile).
// ignore: avoid_unused_parameters
void downloadPdfBlob(Uint8List bytes, String filename) {}
