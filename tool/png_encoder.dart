import 'dart:io';
import 'dart:typed_data';

/// Minimal PNG encoder for brand-asset generation. Writes 8-bit RGB (no
/// alpha channel; required for App Store icons) or RGBA.
class PngEncoder {
  static final List<int> _crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  static int _crc(List<int> bytes) {
    var c = 0xFFFFFFFF;
    for (final b in bytes) {
      c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFF;
  }

  static List<int> _u32(int v) => [
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ];

  static List<int> _chunk(String type, List<int> data) {
    final typed = [...type.codeUnits, ...data];
    return [..._u32(data.length), ...typed, ..._u32(_crc(typed))];
  }

  /// [rgba] is straight (non-premultiplied) RGBA, row-major.
  static Uint8List encode(
    Uint8List rgba,
    int width,
    int height, {
    required bool alpha,
  }) {
    final channels = alpha ? 4 : 3;
    final raw = BytesBuilder();
    for (var y = 0; y < height; y++) {
      raw.addByte(0); // filter: none
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        raw.add(rgba.sublist(i, i + channels));
      }
    }
    final header = [
      ..._u32(width),
      ..._u32(height),
      8, // bit depth
      alpha ? 6 : 2, // colour type: RGBA or RGB
      0,
      0,
      0,
    ];
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      ..._chunk('IHDR', header),
      ..._chunk('IDAT', ZLibCodec(level: 9).encode(raw.toBytes())),
      ..._chunk('IEND', []),
    ]);
  }
}
