import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
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
            colors: [Color(0xFF071B33), Color(0xFF0F3559)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5EEAD4).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      unavailable ? Icons.cloud_off_rounded : Icons.fingerprint_rounded,
                      color: const Color(0xFF5EEAD4),
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    AppConfig.appName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 18),
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
                    const SizedBox(height: 10),
                    Text(
                      auth.error ??
                          'The SmartAttend server is unavailable. Try again shortly.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () => ref
                          .read(authControllerProvider.notifier)
                          .retryBootstrap(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(authControllerProvider.notifier)
                          .signOutLocal(),
                      child: const Text('Sign out'),
                    ),
                  ] else ...[
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF5EEAD4)),
                      ),
                    ),
                    const SizedBox(height: 14),
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
