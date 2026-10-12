import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' as io;

Future<void> downloadOrSaveFile(String fileName, Uint8List bytes) async {
  if (kIsWeb) {
    // For Web, share_plus can trigger a file download using XFile
    await Share.shareXFiles([XFile.fromData(bytes, name: fileName)], text: 'Backup');
  } else if (io.Platform.isWindows) {
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'حفظ قاعدة البيانات',
      fileName: fileName,
      allowedExtensions: ['db'],
      type: FileType.custom,
    );
    if (outputPath != null) {
      if (!outputPath.toLowerCase().endsWith('.db')) {
        outputPath += '.db';
      }
      final file = io.File(outputPath);
      await file.writeAsBytes(bytes);
    }
  } else {
    // Android/iOS
    await Share.shareXFiles([XFile.fromData(bytes, name: fileName)], text: 'Backup');
  }
}
