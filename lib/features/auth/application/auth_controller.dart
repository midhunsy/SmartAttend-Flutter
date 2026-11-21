import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider));
});

final authBootstrapTimeoutProvider = Provider<Duration>((ref) {
  return const Duration(seconds: 25);
});

enum AuthStatus {
  unknown,
  unauthenticated,
  passwordChangeRequired,
  authenticated,
  backendUnavailable,
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.error,
    this.loading = false,
  });

  final AuthStatus status;
  final AuthUser? user;
  final String? error;
  final bool loading;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? error,
    bool? loading,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: clearError ? null : error ?? this.error,
      loading: loading ?? this.loading,
    );
  }
}

enum _BootstrapOutcome { noSession, authenticated, failed }

class _BootstrapResult {
  const _BootstrapResult(this.outcome, {this.user, this.error});

  final _BootstrapOutcome outcome;
  final AuthUser? user;
  final Object? error;
}

class AuthController extends Notifier<AuthState> {
  bool _bootstrapping = false;

  @override
  AuthState build() {
    return const AuthState(status: AuthStatus.unknown, loading: true);
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  SecureStorageService get _storage => ref.read(secureStorageProvider);

  Future<void> bootstrap() async {
    if (_bootstrapping) return;
    _bootstrapping = true;
    state = state.copyWith(
      status: AuthStatus.unknown,
      loading: true,
      clearError: true,
    );

    try {
      final result = await _withTimeout(
        _restoreSession(),
        ref.read(authBootstrapTimeoutProvider),
      );
      if (result.outcome == _BootstrapOutcome.noSession) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      if (result.outcome == _BootstrapOutcome.authenticated) {
        final user = result.user!;
        state = AuthState(
          status: user.mustChangePassword
              ? AuthStatus.passwordChangeRequired
              : AuthStatus.authenticated,
          user: user,
        );
        return;
      }
      _handleBootstrapFailure(result.error!);
    } catch (error) {
      _handleBootstrapFailure(error);
    } finally {
      _bootstrapping = false;
    }
  }

  Future<void> retryBootstrap() => bootstrap();

  void failBootstrap(String message) {
    if (state.status != AuthStatus.unknown) return;
    state = AuthState(
      status: AuthStatus.backendUnavailable,
      error: message,
    );
  }

  Future<void> signOutLocal() async {
    await _clearToken();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<_BootstrapResult> _restoreSession() async {
    String? token;
    try {
      token = await _storage.readToken();
    } catch (_) {
      return const _BootstrapResult(_BootstrapOutcome.noSession);
    }
    if (token == null || token.trim().isEmpty) {
      return const _BootstrapResult(_BootstrapOutcome.noSession);
    }

    try {
      final user = await _repository.me();
      return _BootstrapResult(_BootstrapOutcome.authenticated, user: user);
    } catch (error) {
      return _BootstrapResult(_BootstrapOutcome.failed, error: error);
    }
  }

  void _handleBootstrapFailure(Object error) {
    if (_isSessionFailure(error)) {
      unawaited(_clearToken());
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Your session is no longer valid. Please sign in again.',
      );
      return;
    }
    state = AuthState(
      status: AuthStatus.backendUnavailable,
      error: _readableError(error),
    );
  }

  bool _isSessionFailure(Object error) {
    if (error is! ApiException) return false;
    final code = error.code?.toUpperCase();
    return error.statusCode == 401 ||
        error.statusCode == 403 ||
        code == 'UNAUTHENTICATED' ||
        code == 'SESSION_INVALID' ||
        code == 'SESSION_EXPIRED';
  }

  String _readableError(Object error) {
    if (error is ApiException) {
      if (error.code == 'TIMEOUT') return error.message;
      final status = error.statusCode;
      if (status != null && status >= 500) {
        return 'SmartAttend is temporarily unavailable (HTTP $status). Please try again.';
      }
      if (status == null) {
        return 'Cannot reach SmartAttend. Check your internet connection and try again.';
      }
      return error.message;
    }
    return 'Unable to verify your session. Check your connection and try again.';
  }

  Future<void> _clearToken() async {
    try {
      await _withTimeout(
        _storage.clearToken(),
        const Duration(seconds: 5),
      );
    } catch (_) {
      return;
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final session = await _repository.login(
        identifier: identifier,
        password: password,
      );
      await _persist(session.token, session.user);
      return true;
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: error is ApiException ? error.message : 'Unable to sign in.',
      );
      return false;
    }
  }

  Future<bool> registerCompany({
    required String companyName,
    required String companyEmail,
    required String contactNumber,
    required String industry,
    required String address,
    String? website,
    required String adminFullName,
    required String adminEmail,
    required String adminMobile,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final session = await _repository.registerCompany(
        companyName: companyName,
        companyEmail: companyEmail,
        contactNumber: contactNumber,
        industry: industry,
        address: address,
        website: website,
        adminFullName: adminFullName,
        adminEmail: adminEmail,
        adminMobile: adminMobile,
        username: username,
        password: password,
        confirmPassword: confirmPassword,
      );
      await _persist(session.token, session.user);
      return true;
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: error is ApiException
            ? error.message
            : 'Unable to register the organization.',
      );
      return false;
    }
  }

  Future<bool> changeFirstPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _repository.changeFirstPassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      final current = state.user;
      final user = current != null
          ? current.copyWith(mustChangePassword: false)
          : await _repository.me();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user.copyWith(mustChangePassword: false),
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: error is ApiException
            ? error.message
            : 'Unable to update your password.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _withTimeout(
        _repository.logout(),
        const Duration(seconds: 5),
      );
    } catch (_) {
      return;
    } finally {
      await _clearToken();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _persist(String token, AuthUser user) async {
    if (token.trim().isEmpty) {
      throw const ApiException('Sign-in response did not include a session.');
    }
    try {
      await _storage.saveToken(token);
    } catch (_) {
      throw const ApiException('Secure storage is unavailable on this device.');
    }
    state = AuthState(
      status: user.mustChangePassword
          ? AuthStatus.passwordChangeRequired
          : AuthStatus.authenticated,
      user: user,
    );
  }
}

Future<T> _withTimeout<T>(Future<T> future, Duration timeout) {
  final completer = Completer<T>();
  final timer = Timer(timeout, () {
    if (!completer.isCompleted) {
      completer.completeError(
        const ApiException(
          'SmartAttend did not respond in time. Check your connection and try again.',
          code: 'TIMEOUT',
        ),
      );
    }
  });
  future.then(
    (value) {
      timer.cancel();
      if (!completer.isCompleted) completer.complete(value);
    },
    onError: (Object error, StackTrace stackTrace) {
      timer.cancel();
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    },
  );
  return completer.future;
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
