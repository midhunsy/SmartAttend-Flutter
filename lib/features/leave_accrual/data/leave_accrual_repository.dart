import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../core/utils/json_helpers.dart';
import 'models/leave_accrual_models.dart';

final leaveAccrualRepositoryProvider = Provider<LeaveAccrualRepository>((ref) {
  return LeaveAccrualRepository(ref.read(apiClientProvider).dio);
});

class LeaveAccrualRepository {
  const LeaveAccrualRepository(this._dio);

  final Dio _dio;

  Future<LeaveOverview> loadOverview({String? employeeId}) async {
    final query = <String, String>{};
    final id = employeeId?.trim() ?? '';
    if (id.isNotEmpty) query['employeeId'] = id;
    if (query.isEmpty) {
      await _post('/api/leave-policies/accrue-current');
    }
    final data = await _get('/api/leave-overview', query);
    return LeaveOverview.fromJson(data);
  }

  Future<List<LeaveLedgerEntry>> loadLedger({
    String? employeeId,
    String? leaveType,
  }) async {
    final query = <String, String>{};
    final id = employeeId?.trim() ?? '';
    final type = leaveType?.trim() ?? '';
    if (id.isNotEmpty) query['employeeId'] = id;
    if (type.isNotEmpty) query['leaveType'] = type;
    final data = await _get('/api/leave-ledger', query);
    return asMapList(data['ledger']).map(LeaveLedgerEntry.fromJson).toList();
  }

  Future<LeavePolicyCatalog> loadPolicies() async {
    final data = await _get('/api/leave-policies');
    return LeavePolicyCatalog.fromJson(data);
  }

  Future<String> savePolicy({
    String? policyId,
    required String leaveType,
    required String accrualMethod,
    required double monthlyEntitlement,
    required double annualEntitlement,
    required int creditDay,
    required String accrualTiming,
    required String eligibility,
    required int probationMonths,
    required int prorateByJoiningDate,
    required int carryForward,
    required double carryForwardCap,
    required int expiryMonths,
    required double maxBalance,
    required int fractionalSupport,
    required String effectiveFrom,
  }) async {
    final body = <String, dynamic>{
      'leaveType': leaveType.trim(),
      'accrualMethod': accrualMethod.trim(),
      'monthlyEntitlement': _number(monthlyEntitlement),
      'annualEntitlement': _number(annualEntitlement),
      'creditDay': creditDay,
      'accrualTiming': accrualTiming.trim(),
      'eligibility': eligibility.trim(),
      'probationMonths': probationMonths,
      'prorateByJoiningDate': prorateByJoiningDate,
      'carryForward': carryForward,
      'carryForwardCap': _number(carryForwardCap),
      'expiryMonths': expiryMonths,
      'maxBalance': _number(maxBalance),
      'fractionalSupport': fractionalSupport,
      'effectiveFrom': effectiveFrom.trim(),
    };
    final id = policyId?.trim() ?? '';
    final data = id.isEmpty
        ? await _post('/api/leave-policies', body)
        : await _put('/api/leave-policies/$id', body);
    return asString(data['policy_id'] ?? data['policyId']);
  }

  Future<AccrualRunResult> runAccrual({
    required String policyId,
    required String period,
    List<String>? employeeIds,
  }) async {
    final ids = (employeeIds ?? const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final body = <String, dynamic>{'period': period.trim()};
    if (ids.isNotEmpty) body['employeeIds'] = ids;
    final data = await _post(
      '/api/leave-policies/${policyId.trim()}/accrue',
      body,
    );
    return AccrualRunResult.fromJson(data);
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    try {
      final response = await _dio.get(path, queryParameters: query);
      return asMap(response.data);
    } on DioException catch (error) {
      throw error.toApiException();
    }
  }

  Future<Map<String, dynamic>> _post(String path, [Object? body]) async {
    try {
      final response = await _dio.post(path, data: body);
      return asMap(response.data);
    } on DioException catch (error) {
      throw error.toApiException();
    }
  }

  Future<Map<String, dynamic>> _put(String path, Object body) async {
    try {
      final response = await _dio.put(path, data: body);
      return asMap(response.data);
    } on DioException catch (error) {
      throw error.toApiException();
    }
  }

  num _number(double value) {
    final rounded = value.roundToDouble();
    return value == rounded ? rounded.toInt() : value;
  }
}
