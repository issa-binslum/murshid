import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/auth_provider.dart';
import '../../router/route_names.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFEDF2FB),
      body: isDesktop
          ? Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 340, child: _LeftPanel()),
                  const SizedBox(width: 64), // gap between left and right
                  SizedBox(width: 360, child: const _FormCard()),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const _FormCard(),
                ],
              ),
            ),
    );
  }

  static Widget _buildCrest(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      // If you have the SUZA crest PNG, replace body with:
      // child: Image.asset('assets/suza_crest.png', width: size * 0.65),
      child: Text(
        'S',
        style: TextStyle(
          fontSize: size * 0.5,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF1B2E6B),
        ),
      ),
    );
  }
}

// ── Left branding panel ───────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Crest
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            // Replace with: Image.asset('assets/suza_crest.png', width: 78)
            child: const Text(
              'M',
              style: TextStyle(
                fontSize: 58,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1B2E6B),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'MURSHID',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1B2E6B),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            AppStrings.appTagline,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Kwerekwe Zanzibar',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 24,
            alignment: WrapAlignment.center,
            children: const [
              _SecurityBadge('Encrypted'),
              _SecurityBadge('Secure'),
              _SecurityBadge('Protected'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  final String label;
  const _SecurityBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF16A34A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 11, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

// ── White floating form card ──────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(22),
            blurRadius: 32,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indigo rounded-square avatar — matches screenshot
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            AppStrings.welcomeBack,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            AppStrings.signInSubtitle,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 26),
          const _FormPanel(),
        ],
      ),
    );
  }
}

// ── Form panel — all logic unchanged ─────────────────────────────────────────

class _FormPanel extends ConsumerStatefulWidget {
  const _FormPanel();

  @override
  ConsumerState<_FormPanel> createState() => _FormPanelState();
}

class _FormPanelState extends ConsumerState<_FormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final FocusNode _usernameFocus;
  late final FocusNode _passwordFocus;
  bool _obscure = true;
  bool _rememberMe = false;
  bool _loginSuccess = false;

  @override
  void initState() {
    super.initState();
    _usernameFocus = FocusNode();
    _passwordFocus = FocusNode();
    // Clear any stale error the moment the user starts typing
    _identifierCtrl.addListener(_clearError);
    _passwordCtrl.addListener(_clearError);
  }

  void _clearError() {
    if (ref.read(authProvider).error != null) {
      ref.read(authProvider.notifier).clearError();
    }
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref
        .read(authProvider.notifier)
        .login(_identifierCtrl.text.trim(), _passwordCtrl.text);

    if (!mounted || !ok) return;

    // Show success banner briefly; router redirect handles navigation.
    setState(() => _loginSuccess = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      context.goNamed(RouteNames.dashboard);
    }
    // needsBusinessSelection → router redirects to /pick-business automatically.
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Username ──
          _fieldLabel('Username or Email'),
          const SizedBox(height: 6),
          _buildInput(
            controller: _identifierCtrl,
            hint: 'Enter your username or email',
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            focusNode: _usernameFocus,
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            validator: (v) => (v == null || v.isEmpty)
                ? 'Please enter your email or username'
                : null,
          ),
          const SizedBox(height: 14),

          // ── Password ──
          _fieldLabel('Password'),
          const SizedBox(height: 6),
          _buildInput(
            controller: _passwordCtrl,
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            focusNode: _passwordFocus,
            onFieldSubmitted: (_) => _submit(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: const Color(0xFF9CA3AF),
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password is required' : null,
          ),
          const SizedBox(height: 14),

          // ── Remember me + Forgot password ──
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                  activeColor: const Color(0xFF4F46E5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3)),
                  side: const BorderSide(
                      color: Color(0xFFD1D5DB), width: 1.2),
                ),
              ),
              const SizedBox(width: 7),
              const Text('Remember me',
                  style: TextStyle(fontSize: 12, color: Color(0xFF374151))),
              const Spacer(),
              Flexible(
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    AppStrings.forgotPassword,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4F46E5),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          // ── Success banner ──
          if (_loginSuccess) ...[
            const SizedBox(height: 14),
            _AlertBanner(
              message: 'Login successful! Redirecting…',
              type: _BannerType.success,
            ),
          ],

          // ── Error banner ──
          if (!_loginSuccess && authState.error != null) ...[
            const SizedBox(height: 14),
            _AlertBanner(
              message: authState.error!,
              type: _BannerType.error,
            ),
          ],

          const SizedBox(height: 22),

          // ── Sign In button ──
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: (authState.isLoading || _loginSuccess) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF4F46E5).withAlpha(140),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: (authState.isLoading || _loginSuccess)
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF374151),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      focusNode: focusNode,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.dangerText),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.dangerText, width: 1.5),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

// ── Alert banner ─────────────────────────────────────────────────────────────

enum _BannerType { success, error }

class _AlertBanner extends StatelessWidget {
  final String message;
  final _BannerType type;

  const _AlertBanner({required this.message, required this.type});

  @override
  Widget build(BuildContext context) {
    final isSuccess = type == _BannerType.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSuccess
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess
              ? const Color(0xFF16A34A)
              : const Color(0xFFDC2626),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSuccess
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            size: 16,
            color: isSuccess
                ? const Color(0xFF16A34A)
                : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSuccess
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB91C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

