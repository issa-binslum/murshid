import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_colors.dart';
import '../core/models/auth_response_model.dart';
import '../core/providers/auth_provider.dart';
import '../router/route_names.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar trigger button
// ─────────────────────────────────────────────────────────────────────────────

class BusinessSwitcherWidget extends ConsumerWidget {
  const BusinessSwitcherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final business = auth.currentBusiness;
    final name = business?.name ?? 'Select Business';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            'Active Business',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withAlpha(180),
              letterSpacing: 0.5,
            ),
          ),
        ),
        InkWell(
          onTap: () => _showSwitcher(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: business != null
                        ? AppColors.primaryDark
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: business != null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'B',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16),
                        )
                      : const Icon(Icons.business_rounded,
                          size: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: business != null
                                ? AppColors.textPrimary
                                : AppColors.warningText),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        business?.currency ?? 'No business selected',
                        style: TextStyle(
                            fontSize: 11,
                            color: business != null
                                ? AppColors.textSecondary
                                : AppColors.warningText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.unfold_more_rounded,
                    size: 16, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSwitcher(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authProvider);
    if (auth.businesses.isEmpty) return;

    final router = GoRouter.of(context);
    showDialog(
      context: context,
      builder: (_) => _BusinessSwitcherDialog(
        businesses: auth.businesses,
        activeId: auth.currentBusiness?.id,
        onSwitched: () => router.goNamed(RouteNames.dashboard),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _BusinessSwitcherDialog extends ConsumerStatefulWidget {
  final List<BusinessItem> businesses;
  final String? activeId;
  final VoidCallback onSwitched;

  const _BusinessSwitcherDialog({
    required this.businesses,
    required this.activeId,
    required this.onSwitched,
  });

  @override
  ConsumerState<_BusinessSwitcherDialog> createState() =>
      _BusinessSwitcherDialogState();
}

class _BusinessSwitcherDialogState
    extends ConsumerState<_BusinessSwitcherDialog> {
  String? _switchingId;

  Future<void> _select(String businessId) async {
    if (_switchingId != null) return;
    setState(() => _switchingId = businessId);
    final ok = await ref.read(authProvider.notifier).selectBusiness(businessId);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (ok) widget.onSwitched();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.sidebarBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Switch Business',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select a workspace to work in',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _switchingId != null
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.textSecondary,
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 16),
              // ── Business cards ───────────────────────────────────────────
              ...widget.businesses.map((biz) {
                final isActive = biz.businessId == widget.activeId;
                final isSwitching = _switchingId == biz.businessId;
                final isDisabled =
                    _switchingId != null && _switchingId != biz.businessId;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BusinessCard(
                    biz: biz,
                    isActive: isActive,
                    isSwitching: isSwitching,
                    isDisabled: isDisabled,
                    onTap: isActive || _switchingId != null
                        ? null
                        : () => _select(biz.businessId),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Business card
// ─────────────────────────────────────────────────────────────────────────────

class _BusinessCard extends StatefulWidget {
  final BusinessItem biz;
  final bool isActive;
  final bool isSwitching;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _BusinessCard({
    required this.biz,
    required this.isActive,
    required this.isSwitching,
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
    final initial = widget.biz.businessName.isNotEmpty
        ? widget.biz.businessName[0].toUpperCase()
        : 'B';

    final cardColor = widget.isActive
        ? AppColors.primary.withAlpha(12)
        : _hovered && !widget.isDisabled
            ? const Color(0xFFF8FAFF)
            : Colors.white;

    final borderColor = widget.isActive
        ? AppColors.primary.withAlpha(120)
        : widget.isDisabled
            ? AppColors.border.withAlpha(100)
            : AppColors.border;

    return Opacity(
      opacity: widget.isDisabled ? 0.45 : 1.0,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: widget.isActive
                        ? AppColors.primaryDark
                        : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: widget.isActive
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.biz.businessName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.isActive
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.biz.isOwner ? 'Owner' : widget.biz.roleName}  ·  ${widget.biz.currency}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Trailing
                const SizedBox(width: 8),
                if (widget.isSwitching)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                else if (widget.isActive)
                  const Icon(Icons.check_circle_rounded,
                      size: 20, color: AppColors.primary)
                else
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.border),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
