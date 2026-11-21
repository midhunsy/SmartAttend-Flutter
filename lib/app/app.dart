import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../features/auth/application/auth_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class SmartAttendApp extends StatelessWidget {
  const SmartAttendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: _SmartAttendApp());
  }
}

class _SmartAttendApp extends ConsumerStatefulWidget {
  const _SmartAttendApp();

  @override
  ConsumerState<_SmartAttendApp> createState() => _SmartAttendAppState();
}

class _SmartAttendAppState extends ConsumerState<_SmartAttendApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(authControllerProvider.notifier).bootstrap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
