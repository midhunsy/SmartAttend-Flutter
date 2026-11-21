import '../../../../core/utils/json_helpers.dart';
import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    this.expiresAt,
    required this.requiresPasswordChange,
    required this.user,
  });

  final String token;
  final String? expiresAt;
  final bool requiresPasswordChange;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: asString(json['token']),
      expiresAt: asNullableString(json['expiresAt']),
      requiresPasswordChange: asBool(json['requiresPasswordChange']),
      user: AuthUser.fromJson(asMap(json['user'])),
    );
  }
}
