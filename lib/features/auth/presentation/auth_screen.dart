import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_state_widgets.dart';
import '../application/auth_controller.dart';
import '../data/models/auth_support.dart';

enum AuthMode { login, register, forgot }

extension AuthModePath on AuthMode {
  String get path => switch (this) {
        AuthMode.login => '/login',
        AuthMode.register => '/register',
        AuthMode.forgot => '/forgot-password',
      };
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.login});

  final AuthMode initialMode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _industryController = TextEditingController(text: 'Technology & Software');
  final _addressController = TextEditingController();
  final _websiteController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminMobileController = TextEditingController();
  final _usernameController = TextEditingController();
  final _registrationPasswordController = TextEditingController();
  final _registrationConfirmController = TextEditingController();
  final _forgotIdentifierController = TextEditingController();
  final _resetCodeController = TextEditingController();
  final _resetPasswordController = TextEditingController();
  final _resetConfirmController = TextEditingController();

  bool _obscureLoginPassword = true;
  bool _obscureRegistrationPassword = true;
  bool _obscureResetPassword = true;
  bool _busy = false;
  bool _checkingUsername = false;
  bool _forgotCodeSent = false;
  bool? _usernameAvailable;
  String? _usernameReason;
  String? _error;
  String? _notice;
  AuthHelpInfo? _helpInfo;
  Timer? _usernameDebounce;

  AuthMode get _mode => widget.initialMode;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_scheduleUsernameCheck);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _usernameController.removeListener(_scheduleUsernameCheck);
    for (final controller in <TextEditingController>[
      _identifierController,
      _passwordController,
      _companyNameController,
      _companyEmailController,
      _contactNumberController,
      _industryController,
      _addressController,
      _websiteController,
      _adminNameController,
      _adminEmailController,
      _adminMobileController,
      _usernameController,
      _registrationPasswordController,
      _registrationConfirmController,
      _forgotIdentifierController,
      _resetCodeController,
      _resetPasswordController,
      _resetConfirmController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _scheduleUsernameCheck() {
    _usernameDebounce?.cancel();
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      if (mounted) {
        setState(() {
          _usernameAvailable = null;
          _usernameReason = null;
          _checkingUsername = false;
        });
      }
      return;
    }
    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (mounted) setState(() => _checkingUsername = true);
      try {
        final response =
            await ref.read(authRepositoryProvider).checkUsername(username);
        if (!mounted) return;
        setState(() {
          _checkingUsername = false;
          _usernameAvailable = response['available'] as bool?;
          _usernameReason = response['reason']?.toString();
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _checkingUsername = false;
            _usernameAvailable = null;
          });
        }
      }
    });
  }

  void _navigate(AuthMode mode) {
    if (mode == _mode) return;
    context.go(mode.path);
  }

  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
  }

  void _setError(String? value) {
    if (mounted) setState(() => _error = value);
  }

  Future<void> _submitLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      _setError('Enter your Username or Employee ID and password.');
      return;
    }
    _setBusy(true);
    _setError(null);
    final success = await ref.read(authControllerProvider.notifier).login(
          identifier: identifier,
          password: password,
        );
    if (!success && mounted) {
      _setBusy(false);
      _setError(ref.read(authControllerProvider).error);
    }
  }

  Future<void> _submitRegistration() async {
    if (_companyNameController.text.trim().isEmpty ||
        _companyEmailController.text.trim().isEmpty ||
        _contactNumberController.text.trim().isEmpty ||
        _industryController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _adminNameController.text.trim().isEmpty ||
        _adminEmailController.text.trim().isEmpty ||
        _adminMobileController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _registrationPasswordController.text.isEmpty) {
      _setError('Complete all required company and administrator fields.');
      return;
    }
    if (_usernameAvailable == false) {
      _setError(_usernameReason ?? 'Choose a different global username.');
      return;
    }
    final passwordError = _passwordStrengthError(
      _registrationPasswordController.text,
    );
    if (passwordError != null) {
      _setError(passwordError);
      return;
    }
    if (_registrationPasswordController.text !=
        _registrationConfirmController.text) {
      _setError('Password and Confirm Password do not match.');
      return;
    }

    _setBusy(true);
    _setError(null);
    final success =
        await ref.read(authControllerProvider.notifier).registerCompany(
              companyName: _companyNameController.text,
              companyEmail: _companyEmailController.text,
              contactNumber: _contactNumberController.text,
              industry: _industryController.text,
              address: _addressController.text,
              website: _websiteController.text.trim().isEmpty
                  ? null
                  : _websiteController.text,
              adminFullName: _adminNameController.text,
              adminEmail: _adminEmailController.text,
              adminMobile: _adminMobileController.text,
              username: _usernameController.text,
              password: _registrationPasswordController.text,
              confirmPassword: _registrationConfirmController.text,
            );
    if (!success && mounted) {
      _setBusy(false);
      _setError(ref.read(authControllerProvider).error);
    }
  }

  Future<void> _submitForgotRequest() async {
    final identifier = _forgotIdentifierController.text.trim();
    if (identifier.isEmpty) {
      _setError('Enter your registered email address or username.');
      return;
    }
    _setBusy(true);
    _setError(null);
    try {
      final message =
          await ref.read(authRepositoryProvider).forgotPassword(identifier);
      if (!mounted) return;
      setState(() {
        _forgotCodeSent = true;
        _notice = message;
      });
    } catch (error) {
      _setError(_message(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _submitReset() async {
    final code = _resetCodeController.text.trim();
    final password = _resetPasswordController.text;
    if (code.isEmpty || password.isEmpty) {
      _setError('Enter the verification code and your new password.');
      return;
    }
    final passwordError = _passwordStrengthError(password);
    if (passwordError != null) {
      _setError(passwordError);
      return;
    }
    if (password != _resetConfirmController.text) {
      _setError('Passwords do not match.');
      return;
    }
    _setBusy(true);
    _setError(null);
    try {
      final message =
          await ref.read(authRepositoryProvider).resetPassword(
                token: code,
                newPassword: password,
                confirmPassword: _resetConfirmController.text,
              );
      if (!mounted) return;
      setState(() {
        _forgotCodeSent = false;
        _notice = message;
      });
    } catch (error) {
      _setError(_message(error));
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _openHelp() async {
    try {
      _helpInfo ??= await ref.read(authRepositoryProvider).helpInfo();
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) {
          final info = _helpInfo!;
          return AlertDialog(
            title: const Text('SmartAttend Sign-In Help'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _helpSection('Signing in', info.loginGuidance),
                  _helpSection('Password reset', info.passwordResetGuidance),
                  _helpSection('Troubleshooting', info.troubleshooting),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${info.supportEmail} · ${info.supportPhone}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(info.supportHours, style: const TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      _setError(_message(error));
    }
  }

  Future<void> _showOutbox() async {
    try {
      final messages =
          await ref.read(authRepositoryProvider).sandboxOutbox();
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sandbox Reset Outbox'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: messages.isEmpty
                ? const Text('No verification codes have been issued yet.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: messages.length,
                    separatorBuilder: (_, _) => const Divider(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final item = messages[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.recipientEmail, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${item.subject}\nCode: ${item.resetCode} · ${item.createdAt}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppColors.teal),
                          onPressed: () {
                            _resetCodeController.text = item.resetCode;
                            Navigator.of(context).pop();
                          },
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      _setError(_message(error));
    }
  }

  Widget _helpSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: AppSpacing.xs),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Text('• $item', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                constraints: const BoxConstraints(maxWidth: 1040),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  borderRadius: AppRadius.borderXxl,
                  elevation: 12,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 840;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (wide) Expanded(child: _buildBrand(theme)),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(wide ? AppSpacing.xxl : AppSpacing.lg),
                              child: _buildForm(theme),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.navyDark, AppColors.navySoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xxl),
          bottomLeft: Radius.circular(AppRadius.xxl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.tealLight.withValues(alpha: 0.16),
                  borderRadius: AppRadius.borderMd,
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: AppColors.tealLight,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Text(
                'SmartAttend',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          const Text(
            'Attendance that fits\nyour organization.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Secure, tenant-isolated workforce attendance with GPS-aware '
            'punches, approvals, and role-based dashboards.',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _brandPoint(Icons.shield_rounded, 'Enterprise access control'),
          _brandPoint(Icons.map_rounded, 'Geofenced office punches'),
          _brandPoint(Icons.insights_rounded, 'Role-aware dashboards'),
          const SizedBox(height: AppSpacing.xxl),
          OutlinedButton.icon(
            onPressed: _openHelp,
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: const Text('Sign-in help'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandPoint(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: AppColors.tealLight, size: 20),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) AppMessageBanner(message: _error!, isError: true, onDismiss: () => _setError(null)),
        if (_notice != null) AppMessageBanner(message: _notice!, isError: false),
        if (_error != null || _notice != null) const SizedBox(height: AppSpacing.md),
        switch (_mode) {
          AuthMode.login => _buildLogin(theme),
          AuthMode.register => _buildRegistration(theme),
          AuthMode.forgot => _buildForgot(theme),
        },
      ],
    );
  }

  Widget _buildLogin(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Welcome back', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Sign in with your global username or Employee ID.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        _field(
          label: 'Username or Employee ID',
          controller: _identifierController,
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        _field(
          label: 'Password',
          controller: _passwordController,
          icon: Icons.lock_outline_rounded,
          obscure: _obscureLoginPassword,
          suffix: IconButton(
            icon: Icon(
              _obscureLoginPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(
              () => _obscureLoginPassword = !_obscureLoginPassword,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _navigate(AuthMode.forgot),
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: _busy ? null : _submitLogin,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : const Text('Sign in'),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('New to SmartAttend? ', style: TextStyle(color: AppColors.textSecondary)),
            TextButton(
              onPressed: () => _navigate(AuthMode.register),
              child: const Text('Register company'),
            ),
          ],
        ),
        Center(
          child: TextButton.icon(
            onPressed: _openHelp,
            icon: const Icon(Icons.help_outline_rounded, size: 16),
            label: const Text('Need help signing in?'),
          ),
        ),
      ],
    );
  }

  Widget _buildRegistration(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Create your workspace', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Company details and administrator account.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionLabel('Organization Details'),
        _field(
          label: 'Company name',
          controller: _companyNameController,
          icon: Icons.business_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _field(
          label: 'Official company email',
          controller: _companyEmailController,
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;
            if (isNarrow) {
              return Column(
                children: [
                  _field(
                    label: 'Contact number',
                    controller: _contactNumberController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _field(
                    label: 'Industry',
                    controller: _industryController,
                    icon: Icons.factory_outlined,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _field(
                    label: 'Contact number',
                    controller: _contactNumberController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _field(
                    label: 'Industry',
                    controller: _industryController,
                    icon: Icons.factory_outlined,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _field(
          label: 'Address',
          controller: _addressController,
          icon: Icons.location_on_outlined,
        ),
        const SizedBox(height: AppSpacing.md),
        _field(
          label: 'Website (optional)',
          controller: _websiteController,
          icon: Icons.language_outlined,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: AppSpacing.lg),
        _sectionLabel('Company Administrator'),
        _field(
          label: 'Full name',
          controller: _adminNameController,
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 420;
            if (isNarrow) {
              return Column(
                children: [
                  _field(
                    label: 'Email',
                    controller: _adminEmailController,
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _field(
                    label: 'Mobile',
                    controller: _adminMobileController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _field(
                    label: 'Email',
                    controller: _adminEmailController,
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _field(
                    label: 'Mobile',
                    controller: _adminMobileController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _field(
          label: 'Global username',
          controller: _usernameController,
          icon: Icons.alternate_email_rounded,
          suffix: _checkingUsername
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _usernameAvailable == true
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 18,
                      ),
                    )
                  : null,
          helperText: _usernameReason,
        ),
        const SizedBox(height: AppSpacing.md),
        _field(
          label: 'Password',
          controller: _registrationPasswordController,
          icon: Icons.lock_outline_rounded,
          obscure: _obscureRegistrationPassword,
          suffix: IconButton(
            icon: Icon(
              _obscureRegistrationPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(
              () =>
                  _obscureRegistrationPassword = !_obscureRegistrationPassword,
            ),
          ),
          helperText: 'Minimum 8 characters with uppercase, lowercase, and a number.',
        ),
        const SizedBox(height: AppSpacing.md),
        _field(
          label: 'Confirm password',
          controller: _registrationConfirmController,
          icon: Icons.lock_outline_rounded,
          obscure: _obscureRegistrationPassword,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _busy ? null : _submitRegistration,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : const Text('Register company'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => _navigate(AuthMode.login),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }

  Widget _buildForgot(ThemeData theme) {
    if (!_forgotCodeSent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Reset password', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Enter your registered username or email address.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          _field(
            label: 'Username or email',
            controller: _forgotIdentifierController,
            icon: Icons.mail_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _busy ? null : _submitForgotRequest,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Text('Send verification code'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => _navigate(AuthMode.login),
            child: const Text('Back to sign in'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Verify and reset', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Enter the single-use code sent to your registered inbox.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        _field(
          label: 'Verification code',
          controller: _resetCodeController,
          icon: Icons.numbers_rounded,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: AppSpacing.md),
        _field(
          label: 'New password',
          controller: _resetPasswordController,
          icon: Icons.lock_outline_rounded,
          obscure: _obscureResetPassword,
          suffix: IconButton(
            icon: Icon(
              _obscureResetPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () =>
                setState(() => _obscureResetPassword = !_obscureResetPassword),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _field(
          label: 'Confirm password',
          controller: _resetConfirmController,
          icon: Icons.lock_outline_rounded,
          obscure: _obscureResetPassword,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _busy ? null : _submitReset,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                )
              : const Text('Update password'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: _showOutbox,
          icon: const Icon(Icons.markunread_mailbox_outlined, size: 18),
          label: const Text('Open sandbox outbox'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => _navigate(AuthMode.login),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: AppColors.teal,
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
    String? helperText,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.next,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
        suffixIcon: suffix,
        helperText: helperText,
        helperMaxLines: 2,
      ),
    );
  }

  String? _passwordStrengthError(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must include uppercase, lowercase, and numeric characters.';
    }
    return null;
  }

  String _message(Object error) {
    return error is ApiException
        ? error.message
        : 'Something went wrong. Please try again.';
  }
}
