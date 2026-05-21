import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'desktop_shell.dart';
import 'mobile_shell.dart';

class AdaptiveShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AdaptiveShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    // Use shortestSide so tablets get the desktop shell in both portrait and landscape.
    // Phones (shortestSide ≈ 360–414) stay on MobileShell even when rotated.
    // Tablets and desktops (shortestSide ≥ 600) always use DesktopShell.
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    return shortestSide >= 600
        ? DesktopShell(navigationShell: navigationShell)
        : MobileShell(navigationShell: navigationShell);
  }
}
