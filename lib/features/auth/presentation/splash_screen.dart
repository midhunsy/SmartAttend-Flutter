import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_design.dart';
import '../application/auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _verificationTimeout;

  @override
  void initState() {
    super.initState();
    _verificationTimeout = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      ref.read(authControllerProvider.notifier).failBootstrap(
            'Session verification took too long. Check your connection and try again.',
          );
    });
  }

  @override
  void dispose() {
    _verificationTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final unavailable = auth.status == AuthStatus.backendUnavailable;

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
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: AppColors.tealLight.withValues(alpha: 0.16),
                      borderRadius: AppRadius.borderXl,
                    ),
                    child: Icon(
                      unavailable ? Icons.cloud_off_rounded : Icons.fingerprint_rounded,
                      color: AppColors.tealLight,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text(
                    AppConfig.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (unavailable) ...[
                    const Text(
                      'Unable to verify your session',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Text(
                        auth.error ??
                            'The SmartAttend server is unavailable. Try again shortly.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    FilledButton.icon(
                      onPressed: () => ref
                          .read(authControllerProvider.notifier)
                          .retryBootstrap(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () => ref
                          .read(authControllerProvider.notifier)
                          .signOutLocal(),
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      child: const Text('Sign out'),
                    ),
                  ] else ...[
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.tealLight),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Verifying session…',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
