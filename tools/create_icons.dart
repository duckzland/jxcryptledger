import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() async {
  final inputFile = File('windows/runner/resources/app_icon.ico');
  final outputFile = File('windows/runner/resources/app_icon.ico');

  if (!await inputFile.exists()) {
    print("Error: Input file missing at ${inputFile.path}");
    return;
  }

  final bytes = await inputFile.readAsBytes();
  final decodedImage = img.decodeImage(bytes);
  if (decodedImage == null) {
    print("Error: Could not decode the icon image structure.");
    return;
  }

  print("Generating compliant multi-size PNG-compressed icon...");

  final int s16 = 16;
  final int s32 = 32;
  final int s48 = 48;
  final int s256 = 256;
  final targetSizes = [s16, s32, s48, s256];

  final List<Uint8List> frameBlobs = [];
  final List<Map<String, int>> dirMeta = [];

  for (int size in targetSizes) {
    final resized = img.copyResize(decodedImage, width: size, height: size);
    final rawPng = Uint8List.fromList(img.encodePng(resized));
    frameBlobs.add(rawPng);

    dirMeta.add({
      'width': size == 256 ? 0 : size,
      'height': size == 256 ? 0 : size,
      'size': rawPng.length,
    });
  }

  final int count = targetSizes.length;
  final int headerAndDirSize = 6 + (count * 16);
  final newFileBuffer = BytesBuilder();

  final mainHeader = ByteData(6);
  mainHeader.setUint16(0, 0, Endian.little);
  mainHeader.setUint16(2, 1, Endian.little);
  mainHeader.setUint16(4, count, Endian.little);
  newFileBuffer.add(mainHeader.buffer.asUint8List());

  int currentDataOffset = headerAndDirSize;
  for (int i = 0; i < count; i++) {
    final meta = dirMeta[i];
    final blob = frameBlobs[i];

    final dirEntry = ByteData(16);
    dirEntry.setUint8(0, meta['width']!);
    dirEntry.setUint8(1, meta['height']!);
    dirEntry.setUint8(2, 0);
    dirEntry.setUint8(3, 0);
    dirEntry.setUint16(4, 1, Endian.little);
    dirEntry.setUint16(6, 32, Endian.little);
    dirEntry.setUint32(8, meta['size']!, Endian.little);
    dirEntry.setUint32(12, currentDataOffset, Endian.little);

    newFileBuffer.add(dirEntry.buffer.asUint8List());
    currentDataOffset += blob.length;
  }

  for (final blob in frameBlobs) {
    newFileBuffer.add(blob);
  }

  await outputFile.writeAsBytes(newFileBuffer.toBytes());
  print("Success! All-PNG multi-size 'app_icon.ico' written safely.");
}
