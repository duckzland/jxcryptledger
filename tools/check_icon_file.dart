import 'dart:io';
import 'dart:typed_data';

void main() async {
  final file = File('windows/runner/resources/app_icon.ico');
  if (!await file.exists()) {
    print("Error: File not found.");
    exit(2);
  }

  final bytes = await file.readAsBytes();
  final buffer = ByteData.sublistView(bytes);

  final reserved = buffer.getUint16(0, Endian.little);
  final type = buffer.getUint16(2, Endian.little);
  final count = buffer.getUint16(4, Endian.little);

  if (reserved != 0 || type != 1) {
    print("Not a valid Windows ICO file.");
    exit(3);
  }

  print("Icon contains $count frames:");
  bool foundPng = false;

  for (int i = 0; i < count; i++) {
    int offset = 6 + (i * 16);
    int width = bytes[offset];
    int height = bytes[offset + 1];
    int size = buffer.getUint32(offset + 8, Endian.little);
    int fileOffset = buffer.getUint32(offset + 12, Endian.little);

    bool isPng = false;
    if (fileOffset + 4 <= bytes.length) {
      if (bytes[fileOffset] == 0x89 && bytes[fileOffset + 1] == 0x50 && bytes[fileOffset + 2] == 0x4E && bytes[fileOffset + 3] == 0x47) {
        isPng = true;
        foundPng = true; // Mark that we caught a problematic compressed layer
      }
    }

    final displayWidth = width == 0 ? 256 : width;
    final displayHeight = height == 0 ? 256 : height;
    print(
      " - Size: $size - ${displayWidth}x${displayHeight}, Format: ${isPng ? 'PNG Compressed (Fails RC compiler)' : 'Standard DIB/BMP'}",
    );
  }

  if (foundPng) {
    print("\n[!] Bad icon detected: PNG compressed frame will break the build.");
    exit(1);
  } else {
    print("\n[+] Icon is safe! All frames are standard uncompressed DIB/BMP layouts.");
    exit(0);
  }
}
