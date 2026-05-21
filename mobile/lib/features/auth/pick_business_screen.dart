import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/auth_provider.dart';
import '../../router/route_names.dart';

class PickBusinessScreen extends ConsumerStatefulWidget {
  const PickBusinessScreen({super.key});

  @override
  ConsumerState<PickBusinessScreen> createState() => _PickBusinessScreenState();
}

class _PickBusinessScreenState extends ConsumerState<PickBusinessScreen> {
  String? _selectingId;

  Future<void> _select(String businessId) async {
    setState(() => _selectingId = businessId);
    final ok = await ref.read(authProvider.notifier).selectBusiness(businessId);
    if (!mounted) return;
    if (ok) {
      context.goNamed(RouteNames.dashboard);
    } else {
      setState(() => _selectingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final businesses = auth.businesses;
    final isDesktop = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: const Color(0xFFEDF2FB),
      body: isDesktop
          ? _DesktopLayout(
              businesses: businesses,
              selectingId: _selectingId,
              error: auth.error,
              onSelect: _select,
              onLogout: () => ref.read(authProvider.notifier).logout(),
            )
          : _MobileLayout(
              businesses: businesses,
              selectingId: _selectingId,
              error: auth.error,
              onSelect: _select,
              onLogout: () => ref.read(authProvider.notifier).logout(),
            ),
    );
  }
}

// ── Desktop ───────────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final List businesses;
  final String? selectingId;
  final String? error;
  final void Function(String) onSelect;
  final VoidCallback onLogout;

  const _DesktopLayout({
    required this.businesses,
    required this.selectingId,
    required this.error,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left branding strip
        Container(
          width: 320,
          color: const Color(0xFF1B2E6B),
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'M',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'MURSHID',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Select the business you want\nto work with today.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.white.withAlpha(178),
                ),
              ),
              const SizedBox(height: 40),
              _LogoutLink(onTap: onLogout),
            ],
          ),
        ),
        // Right picker area
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: _PickerContent(
                businesses: businesses,
                selectingId: selectingId,
                error: error,
                onSelect: onSelect,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Mobile ────────────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final List businesses;
  final String? selectingId;
  final String? error;
  final void Function(String) onSelect;
  final VoidCallback onLogout;

  const _MobileLayout({
    required this.businesses,
    required this.selectingId,
    required this.error,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2E6B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'M',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MURSHID',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B2E6B),
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'Business Management',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 36),
            _PickerContent(
              businesses: businesses,
              selectingId: selectingId,
              error: error,
              onSelect: onSelect,
            ),
            const SizedBox(height: 24),
            Center(child: _LogoutLink(onTap: onLogout)),
          ],
        ),
      ),
    );
  }
}

// ── Shared picker content ─────────────────────────────────────────────────────

class _PickerContent extends StatelessWidget {
  final List businesses;
  final String? selectingId;
  final String? error;
  final void Function(String) onSelect;

  const _PickerContent({
    required this.businesses,
    required this.selectingId,
    required this.error,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a Business',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'You belong to ${businesses.length} businesses. Select one to continue.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(message: error!),
        ],
        const SizedBox(height: 24),
        ...businesses.map((biz) => _BusinessCard(
              businessId: biz.businessId as String,
              name: biz.businessName as String,
              currency: biz.currency as String,
              isSelecting: selectingId == biz.businessId,
              isDisabled: selectingId != null,
              onTap: () => onSelect(biz.businessId as String),
            )),
      ],
    );
  }
}

// ── Business card ─────────────────────────────────────────────────────────────

class _BusinessCard extends StatefulWidget {
  final String businessId;
  final String name;
  final String currency;
  final bool isSelecting;
  final bool isDisabled;
  final VoidCallback onTap;

  const _BusinessCard({
    required this.businessId,
    required this.name,
    required this.currency,
    required this.isSelecting,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  State<_BusinessCard> createState() => _BusinessCardState();
}

class _BusinessCardState extends State<_BusinessCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelecting;
    final disabled = widget.isDisabled && !active;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF4F46E5).withAlpha(10)
                : _hovered && !disabled
                    ? Colors.white
                    : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? const Color(0xFF4F46E5)
                  : _hovered && !disabled
                      ? const Color(0xFF4F46E5).withAlpha(80)
                      : const Color(0xFFE5E7EB),
              width: active ? 2 : 1.5,
            ),
            boxShadow: (_hovered && !disabled) || active
                ? [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withAlpha(20),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled ? null : widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Opacity(
                opacity: disabled ? 0.5 : 1.0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      // Initials avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.name.isNotEmpty
                              ? widget.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Name + currency
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.currency,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right icon / spinner
                      const SizedBox(width: 8),
                      active
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF4F46E5),
                              ),
                            )
                          : Icon(
                              Icons.chevron_right_rounded,
                              size: 22,
                              color: _hovered && !disabled
                                  ? const Color(0xFF4F46E5)
                                  : const Color(0xFFD1D5DB),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDC2626)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logout link ───────────────────────────────────────────────────────────────

class _LogoutLink extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.logout_rounded, size: 15),
      label: const Text('Sign in with a different account'),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF6B7280),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}
