import '../../../../core/utils/json_helpers.dart';

class AuthHelpInfo {
  const AuthHelpInfo({
    required this.loginGuidance,
    required this.passwordResetGuidance,
    required this.troubleshooting,
    required this.supportEmail,
    required this.supportPhone,
    required this.supportHours,
  });

  final List<String> loginGuidance;
  final List<String> passwordResetGuidance;
  final List<String> troubleshooting;
  final String supportEmail;
  final String supportPhone;
  final String supportHours;

  factory AuthHelpInfo.fromJson(Map<String, dynamic> json) {
    final support = asMap(json['supportContact']);
    return AuthHelpInfo(
      loginGuidance: asStringList(json['loginGuidance']),
      passwordResetGuidance: asStringList(json['passwordResetGuidance']),
      troubleshooting: asStringList(json['troubleshooting']),
      supportEmail: asString(support['email']),
      supportPhone: asString(support['phone']),
      supportHours: asString(support['hours']),
    );
  }
}

class OutboxMessage {
  const OutboxMessage({
    required this.id,
    required this.recipientEmail,
    required this.subject,
    required this.resetCode,
    required this.createdAt,
  });

  final String id;
  final String recipientEmail;
  final String subject;
  final String resetCode;
  final String createdAt;

  factory OutboxMessage.fromJson(Map<String, dynamic> json) {
    return OutboxMessage(
      id: asString(json['id']),
      recipientEmail: asString(json['recipient_email']),
      subject: asString(json['subject']),
      resetCode: asString(json['reset_code']),
      createdAt: asString(json['created_at']),
    );
  }
}

List<String> asStringList(dynamic value) {
  if (value is! List) return <String>[];
  return value.map((item) => item.toString()).toList();
}
