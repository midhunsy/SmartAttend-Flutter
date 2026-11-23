import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_state_widgets.dart';
import '../application/auth_controller.dart';

class ForcePasswordChangeScreen extends ConsumerStatefulWidget {
  const ForcePasswordChangeScreen({super.key});

  @override
  ConsumerState<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState
    extends ConsumerState<ForcePasswordChangeScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_currentController.text.isEmpty ||
        _newController.text.isEmpty ||
        _confirmController.text.isEmpty) {
      setState(() => _error = 'All password fields are required.');
      return;
    }
    if (_newController.text.length < 8 ||
        !RegExp(r'[A-Z]').hasMatch(_newController.text) ||
        !RegExp(r'[a-z]').hasMatch(_newController.text) ||
        !RegExp(r'[0-9]').hasMatch(_newController.text)) {
      setState(
        () => _error =
            'Password must be at least 8 characters with uppercase, lowercase, and a number.',
      );
      return;
    }
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'New password and confirmation do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final success =
        await ref.read(authControllerProvider.notifier).changeFirstPassword(
              currentPassword: _currentController.text,
              newPassword: _newController.text,
              confirmPassword: _confirmController.text,
            );
    if (!success && mounted) {
      setState(() {
        _busy = false;
        _error = ref.read(authControllerProvider).error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.navyDark, AppColors.navy],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.warningContainer,
                            borderRadius: AppRadius.borderLg,
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            color: AppColors.warning,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Set your personal password',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${user?.fullName ?? 'Your account'} is using a temporary password. Choose a new one to unlock the workspace.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppMessageBanner(
                          message: _error!,
                          isError: true,
                          onDismiss: () => setState(() => _error = null),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      _field(
                        label: 'Temporary password',
                        controller: _currentController,
                        icon: Icons.key_outlined,
                        obscure: _obscure,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        label: 'New password',
                        controller: _newController,
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        label: 'Confirm new password',
                        controller: _confirmController,
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Update password'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).logout(),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Sign out'),
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

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
        suffixIcon: suffix,
      ),
    );
  }
}
