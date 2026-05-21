import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure minimum window size on desktop platforms
  await _initWindowManager();

  runApp(const ProviderScope(child: App()));
}

Future<void> _initWindowManager() async {
  try {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('TradeCore');
    await windowManager.setMinimumSize(const Size(400, 600));
    await windowManager.setSize(const Size(1280, 800));
    await windowManager.center();
    await windowManager.show();
  } catch (_) {
    // window_manager is a no-op on mobile — ignore errors
  }
}
