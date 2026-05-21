import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'desktop_shell.dart';
import 'mobile_shell.dart';

class AdaptiveShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AdaptiveShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return isDesktop
        ? DesktopShell(navigationShell: navigationShell)
        : MobileShell(navigationShell: navigationShell);
  }
}
