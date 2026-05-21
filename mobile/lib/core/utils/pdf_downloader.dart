import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

/// Opens [bytes] as [filename]:
/// • Mobile (Android/iOS) — triggers the OS share sheet so the user can open
///   the PDF in any viewer app or save it to Files.
/// • Desktop (Windows/macOS/Linux) — saves to the Downloads folder and opens
///   with the OS default viewer.
Future<void> saveAndOpenPdf(
    BuildContext context, Uint8List bytes, String filename) async {
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } else {
      final dir =
          await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      await _openDesktopFile(file.path);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open PDF: $e')),
      );
    }
  }
}

Future<void> _openDesktopFile(String path) async {
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', path]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [path]);
  } else {
    await Process.run('xdg-open', [path]);
  }
}
