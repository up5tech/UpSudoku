#!/usr/bin/env dart
/// Generates the launcher icon and the splash artwork from code, so the
/// repository carries no externally sourced images (PLAN.md §25.4).
///
/// Run from the Flutter project:
///
///     dart run tool/generate_icon.dart
///
/// It writes:
/// - `assets/images/icon.png` — 1024×1024 launcher icon (full bleed).
/// - `assets/images/icon_foreground.png` — 1024×1024 adaptive foreground on a
///   transparent canvas (safe zone respected).
/// - `android/app/src/main/res/drawable-nodpi/launch_image.png` — splash art.
/// - `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage*.png`.
///
/// After that run `dart run flutter_launcher_icons` to build the platform
/// icons.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int _size = 1024;

/// Corners of the gradient background.
const List<int> _bgTop = [0x4C, 0x61, 0xD6];
const List<int> _bgBottom = [0x28, 0x35, 0x93];

void main() {
  final root = File.fromUri(Platform.script).parent.parent.path;

  final icon = _canvas(minX: 0, size: _size, transparent: false);
  _drawLogo(icon, scale: 1.0);
  _write('$root/assets/images/icon.png', _encodePng(_size, _size, icon));

  const foregroundSize = 1024;
  final foreground = _canvas(
    minX: 0,
    size: foregroundSize,
    transparent: true,
  );
  _drawLogo(foreground, scale: 0.62);
  _write(
    '$root/assets/images/icon_foreground.png',
    _encodePng(foregroundSize, foregroundSize, foreground),
  );

  final splash = _render(512, scale: 0.78, transparent: true);
  _write(
    '$root/android/app/src/main/res/drawable-nodpi/launch_image.png',
    splash,
  );

  final iosImages = {
    'LaunchImage.png': _render(256, scale: 0.78, transparent: true),
    'LaunchImage@2x.png': _render(512, scale: 0.78, transparent: true),
    'LaunchImage@3x.png': _render(768, scale: 0.78, transparent: true),
  };
  for (final entry in iosImages.entries) {
    _write(
      '$root/ios/Runner/Assets.xcassets/LaunchImage.imageset/${entry.key}',
      entry.value,
    );
  }
}

/// Paints the logo (a 3×3 mini grid) into a transparent or gradient canvas.
Uint8List _render(int size, {required double scale, required bool transparent}) {
  final pixels = _canvas(minX: 0, size: size, transparent: transparent);
  _drawLogo(pixels, scale: scale, side: size);
  return _encodePng(size, size, pixels);
}

/// RGBA buffer with the gradient background filled in.
///
/// `minX` is unused by the painters but keeps the signature stable when the
/// canvas grows a margin.
Uint8List _canvas({required int minX, required int size, required bool transparent}) {
  final pixels = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final index = (y * size + x) * 4;
      if (transparent) continue;
      final t = (x + y) / (2 * size);
      pixels[index] = _lerp(_bgTop[0], _bgBottom[0], t);
      pixels[index + 1] = _lerp(_bgTop[1], _bgBottom[1], t);
      pixels[index + 2] = _lerp(_bgTop[2], _bgBottom[2], t);
      pixels[index + 3] = 255;
    }
  }
  return pixels;
}

int _lerp(int a, int b, double t) => (a + (b - a) * t).round().clamp(0, 255);

void _drawLogo(Uint8List pixels, {required double scale, int side = _size}) {
  // The grid is 634/1024 of the icon; `scale` shrinks it for the adaptive
  // foreground and the splash art.
  final cell = 190.0 * scale * side / _size;
  final gap = 32.0 * scale * side / _size;
  final total = cell * 3 + gap * 2;
  final left = (side - total) / 2;
  final top = left;
  final radius = 30.0 * scale * side / _size;

  const filled = {0, 4, 8};
  const accentCell = 2;
  const accent = [0xFF, 0xC1, 0x07];

  for (var row = 0; row < 3; row++) {
    for (var col = 0; col < 3; col++) {
      final index = row * 3 + col;
      final x0 = left + col * (cell + gap);
      final y0 = top + row * (cell + gap);
      if (index == accentCell) {
        _roundedRect(pixels, side, x0, y0, cell, cell, radius, accent, 255);
      } else if (filled.contains(index)) {
        _roundedRect(
          pixels,
          side,
          x0,
          y0,
          cell,
          cell,
          radius,
          const [255, 255, 255],
          240,
        );
      } else {
        _roundedOutline(
          pixels,
          side,
          x0,
          y0,
          cell,
          cell,
          radius,
          const [255, 255, 255],
          150,
          math.max(4, (10 * scale * side / _size).round()),
        );
      }
    }
  }
}

void _roundedRect(
  Uint8List pixels,
  int side,
  double x,
  double y,
  double w,
  double h,
  double radius,
  List<int> color,
  int alpha,
) {
  final x0 = x.floor();
  final y0 = y.floor();
  final x1 = (x + w).ceil();
  final y1 = (y + h).ceil();
  for (var py = y0; py < y1; py++) {
    for (var px = x0; px < x1; px++) {
      if (px < 0 || py < 0 || px >= side || py >= side) continue;
      if (!_insideRounded(px + 0.5, py + 0.5, x, y, w, h, radius)) continue;
      _blend(pixels, side, px, py, color, alpha);
    }
  }
}

void _roundedOutline(
  Uint8List pixels,
  int side,
  double x,
  double y,
  double w,
  double h,
  double radius,
  List<int> color,
  int alpha,
  int thickness,
) {
  final x0 = x.floor();
  final y0 = y.floor();
  final x1 = (x + w).ceil();
  final y1 = (y + h).ceil();
  for (var py = y0; py < y1; py++) {
    for (var px = x0; px < x1; px++) {
      if (px < 0 || py < 0 || px >= side || py >= side) continue;
      final cx = px + 0.5;
      final cy = py + 0.5;
      final inside = _insideRounded(cx, cy, x, y, w, h, radius);
      final inner = _insideRounded(
        cx,
        cy,
        x + thickness,
        y + thickness,
        w - thickness * 2,
        h - thickness * 2,
        math.max(0, radius - thickness),
      );
      if (inside && !inner) _blend(pixels, side, px, py, color, alpha);
    }
  }
}

bool _insideRounded(
  double px,
  double py,
  double x,
  double y,
  double w,
  double h,
  double radius,
) {
  if (px < x || py < y || px > x + w || py > y + h) return false;
  final left = px < x + radius;
  final right = px > x + w - radius;
  final topY = py < y + radius;
  final bottomY = py > y + h - radius;
  if ((left || right) && (topY || bottomY)) {
    final cx = left ? x + radius : x + w - radius;
    final cy = topY ? y + radius : y + h - radius;
    final dx = px - cx;
    final dy = py - cy;
    return dx * dx + dy * dy <= radius * radius;
  }
  return true;
}

void _blend(Uint8List pixels, int side, int x, int y, List<int> color, int alpha) {
  final index = (y * side + x) * 4;
  final a = alpha / 255.0;
  final dstA = pixels[index + 3] / 255.0;
  final outA = a + dstA * (1 - a);
  if (outA <= 0) return;
  for (var c = 0; c < 3; c++) {
    final dst = pixels[index + c] / 255.0;
    final src = color[c] / 255.0;
    pixels[index + c] = ((src * a + dst * dstA * (1 - a)) / outA * 255)
        .round()
        .clamp(0, 255);
  }
  pixels[index + 3] = (outA * 255).round().clamp(0, 255);
}

void _write(String path, Uint8List bytes) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  stdout.writeln('wrote $path (${bytes.length} bytes)');
}

/// Minimal PNG encoder: 8-bit RGBA, no interlacing.
Uint8List _encodePng(int width, int height, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: none
    raw.add(rgba.sublist(y * width * 4, (y + 1) * width * 4));
  }
  final compressed = ZLibCodec(level: 9).encode(raw.takeBytes());

  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // colour type: RGBA
    ..setUint8(10, 0) // deflate
    ..setUint8(11, 0) // adaptive filtering
    ..setUint8(12, 0); // no interlace

  final out = BytesBuilder()
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add(_chunk('IHDR', header.buffer.asUint8List()))
    ..add(_chunk('IDAT', compressed))
    ..add(_chunk('IEND', const []));
  return out.takeBytes();
}

Uint8List _chunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final length = ByteData(4)..setUint32(0, data.length);
  final crc = _crc32([...typeBytes, ...data]);
  final crcData = ByteData(4)..setUint32(0, crc);
  return Uint8List.fromList([
    ...length.buffer.asUint8List(),
    ...typeBytes,
    ...data,
    ...crcData.buffer.asUint8List(),
  ]);
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
