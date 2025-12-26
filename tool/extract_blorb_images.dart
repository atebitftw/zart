// Tool to extract image resources from a Blorb file for testing.
//
// Usage: dart run tool/extract_blorb_images.dart

import 'dart:io';
import 'package:zart/src/loaders/blorb_resource_manager.dart';

void main() async {
  final blorbPath = 'assets/games/monkey.gblorb';
  final outputDir = 'tool/extracted_images';

  print('Loading Blorb file: $blorbPath');

  final file = File(blorbPath);
  if (!await file.exists()) {
    print('ERROR: Blorb file not found at $blorbPath');
    exit(1);
  }

  final bytes = await file.readAsBytes();
  print('File size: ${bytes.length} bytes');

  final manager = BlorbResourceManager(bytes);

  final imageIds = manager.imageIds;
  print('Found ${imageIds.length} image resources: $imageIds');

  if (imageIds.isEmpty) {
    print('No images found in Blorb file.');
    exit(0);
  }

  // Create output directory
  final outDir = Directory(outputDir);
  if (!await outDir.exists()) {
    await outDir.create(recursive: true);
  }

  // Extract each image
  for (final id in imageIds) {
    final image = manager.getImage(id);
    if (image == null) {
      print('  Image $id: Failed to retrieve');
      continue;
    }

    final ext = image.format == BlorbImageFormat.png ? 'png' : 'jpg';
    final outPath = '$outputDir/image_$id.$ext';

    await File(outPath).writeAsBytes(image.data);
    print('  Image $id: Saved to $outPath (${image.data.length} bytes, $ext)');
  }

  print('\nDone! Extracted ${imageIds.length} images to $outputDir/');
}
