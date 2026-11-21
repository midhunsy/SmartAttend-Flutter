import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            colors: [Color(0xFF071B33), Color(0xFF0F3559)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            color: Color(0xFFB45309),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Set your personal password',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${user?.fullName ?? 'Your account'} is using a temporary password. Choose a new one to unlock the workspace.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        _field(
                          label: 'Temporary password',
                          controller: _currentController,
                          icon: Icons.key_outlined,
                          obscure: _obscure,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          label: 'New password',
                          controller: _newController,
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Update password'),
                        ),
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
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
