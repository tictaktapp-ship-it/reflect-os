// dart run tool/pad_icon.dart
//
// Reads assets/branding/icon-1024.png, scales it to 80% of the canvas,
// centres it on a 1024×1024 transparent canvas, and writes
// assets/branding/icon-1024-padded.png.
// Run after any icon change to regenerate the padded version.

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const int canvasSize = 1024;
  const double scale = 0.80; // icon occupies 80% → 20% padding overall

  final src = img.decodeImage(
    File('assets/branding/icon-1024.png').readAsBytesSync(),
  )!;

  final scaledSize = (canvasSize * scale).round(); // 819
  final offset = ((canvasSize - scaledSize) / 2).round(); // 102 on each side

  final scaled = img.copyResize(src, width: scaledSize, height: scaledSize,
      interpolation: img.Interpolation.cubic);

  final canvas = img.Image(width: canvasSize, height: canvasSize,
      numChannels: 4); // transparent RGBA

  img.compositeImage(canvas, scaled, dstX: offset, dstY: offset);

  File('assets/branding/icon-1024-padded.png')
      .writeAsBytesSync(img.encodePng(canvas));

  print('Written: assets/branding/icon-1024-padded.png '
      '(${scaledSize}px icon centred on ${canvasSize}px canvas)');
}
