import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Saves [bytes] as [filename] in the Downloads folder then opens it with
/// the OS default viewer (works on Windows, macOS, Linux).
Future<void> saveAndOpenPdf(
    BuildContext context, Uint8List bytes, String filename) async {
  try {
    final dir =
        await getDownloadsDirectory() ?? await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await _openFile(file.path);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save PDF: $e')),
      );
    }
  }
}

Future<void> _openFile(String path) async {
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', path]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [path]);
  } else {
    await Process.run('xdg-open', [path]);
  }
}
