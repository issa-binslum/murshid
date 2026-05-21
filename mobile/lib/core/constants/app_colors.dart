import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF2563EB);   // active blue
  static const Color primaryDark = Color(0xFF0F2557); // navy (login, logo)
  static const Color accent = Color(0xFFE8A020);    // amber

  // Backgrounds
  static const Color pageBackground = Color(0xFFF7F8FA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color sidebarBackground = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);

  // Borders & dividers
  static const Color border = Color(0xFFE5E7EB);

  // Status badges
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color successText = Color(0xFF166534);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningText = Color(0xFF92400E);
  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color dangerText = Color(0xFF991B1B);

  // Sidebar nav item states
  static const Color navActiveBg = Color(0xFFEFF6FF);    // light blue tint
  static const Color navActiveBorder = Color(0xFF2563EB);
  static const Color navActiveText = Color(0xFF1D4ED8);
  static const Color navInactiveText = Color(0xFF1A1A2E);

  // Stat card accent colors
  static const Color cardBlue = Color(0xFF2563EB);
  static const Color cardGreen = Color(0xFF16A34A);
  static const Color cardAmber = Color(0xFFD97706);
  static const Color cardPurple = Color(0xFF7C3AED);
  static const Color cardRed = Color(0xFFDC2626);
  static const Color cardCyan = Color(0xFF0891B2);
  static const Color cardOrange = Color(0xFFEA580C);
  static const Color cardTeal = Color(0xFF0D9488);
  static const Color cardIndigo = Color(0xFF4F46E5);

  // Sidebar icon colors per nav item
  static const Color iconDashboard = Color(0xFF2563EB);
  static const Color iconAccounts = Color(0xFF4F46E5);
  static const Color iconReceipts = Color(0xFF059669);
  static const Color iconPayments = Color(0xFF0891B2);
  static const Color iconSales = Color(0xFFD97706);
  static const Color iconPurchases = Color(0xFFEA580C);
  static const Color iconCustomers = Color(0xFF16A34A);
  static const Color iconSuppliers = Color(0xFF0D9488);
  static const Color iconInventory = Color(0xFF7C3AED);
  static const Color iconUsers = Color(0xFF2563EB);
  static const Color iconRoles = Color(0xFFDC2626);
  static const Color iconBusinesses = Color(0xFF1E40AF);
  static const Color iconReports = Color(0xFF6D28D9);
  static const Color iconAudit = Color(0xFF0284C7);

  // Legacy aliases kept for login screen
  static const Color sidebarInactiveText = Color(0x80FFFFFF);
  static const Color sidebarSectionLabel = Color(0x4DFFFFFF);
  static const Color sidebarActiveOverlay = Color(0x17FFFFFF);
}
