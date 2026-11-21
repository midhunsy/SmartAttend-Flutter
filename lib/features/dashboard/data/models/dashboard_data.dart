import '../../../../core/utils/json_helpers.dart';

class DashboardTotals {
  const DashboardTotals({
    required this.totalCompanies,
    required this.activeCompanies,
    required this.totalUsers,
    required this.totalEmployees,
  });

  final int totalCompanies;
  final int activeCompanies;
  final int totalUsers;
  final int totalEmployees;

  factory DashboardTotals.fromJson(Map<String, dynamic> json) {
    return DashboardTotals(
      totalCompanies: asInt(json['total_companies']),
      activeCompanies: asInt(json['active_companies']),
      totalUsers: asInt(json['total_users']),
      totalEmployees: asInt(json['total_employees']),
    );
  }
}

class CompanySummary {
  const CompanySummary({
    required this.companyId,
    required this.companyName,
    required this.companyEmail,
    required this.industry,
    required this.status,
    required this.employeeCount,
    required this.activeUsers,
  });

  final String companyId;
  final String companyName;
  final String companyEmail;
  final String industry;
  final String status;
  final int employeeCount;
  final int activeUsers;

  bool get isActive => status == 'active';

  factory CompanySummary.fromJson(Map<String, dynamic> json) {
    return CompanySummary(
      companyId: asString(json['company_id']),
      companyName: asString(json['company_name']),
      companyEmail: asString(json['company_email']),
      industry: asString(json['industry']),
      status: asString(json['status']),
      employeeCount: asInt(json['employee_count']),
      activeUsers: asInt(json['active_users']),
    );
  }
}

class DashboardHeadcount {
  const DashboardHeadcount({
    required this.totalEmployees,
    required this.activeEmployees,
  });

  final int totalEmployees;
  final int activeEmployees;

  factory DashboardHeadcount.fromJson(Map<String, dynamic> json) {
    return DashboardHeadcount(
      totalEmployees: asInt(json['total_employees']),
      activeEmployees: asInt(json['active_employees']),
    );
  }
}

class TodayAttendance {
  const TodayAttendance({
    required this.checkedInCount,
    required this.lateCount,
    required this.wfhCount,
  });

  final int checkedInCount;
  final int lateCount;
  final int wfhCount;

  factory TodayAttendance.fromJson(Map<String, dynamic> json) {
    return TodayAttendance(
      checkedInCount: asInt(json['checked_in_count']),
      lateCount: asInt(json['late_count']),
      wfhCount: asInt(json['wfh_count']),
    );
  }
}

class PendingApprovals {
  const PendingApprovals({
    required this.pendingLeaves,
    required this.pendingRegularizations,
    required this.pendingWfh,
  });

  final int pendingLeaves;
  final int pendingRegularizations;
  final int pendingWfh;

  int get total => pendingLeaves + pendingRegularizations + pendingWfh;

  factory PendingApprovals.fromJson(Map<String, dynamic> json) {
    return PendingApprovals(
      pendingLeaves: asInt(json['pending_leaves']),
      pendingRegularizations: asInt(json['pending_regs']),
      pendingWfh: asInt(json['pending_wfh']),
    );
  }
}

class DepartmentCount {
  const DepartmentCount({required this.department, required this.count});

  final String department;
  final int count;

  factory DepartmentCount.fromJson(Map<String, dynamic> json) {
    return DepartmentCount(
      department: asString(json['department'], 'Unassigned'),
      count: asInt(json['count']),
    );
  }
}

class HolidayItem {
  const HolidayItem({
    required this.holidayId,
    required this.name,
    required this.date,
    required this.type,
  });

  final String holidayId;
  final String name;
  final String date;
  final String type;

  factory HolidayItem.fromJson(Map<String, dynamic> json) {
    return HolidayItem(
      holidayId: asString(json['holiday_id']),
      name: asString(json['name']),
      date: asString(json['holiday_date']),
      type: asString(json['holiday_type']),
    );
  }
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.attendanceId,
    required this.attendanceDate,
    this.checkInTime,
    this.checkOutTime,
    required this.workingHours,
    required this.status,
    this.employeeName,
    this.employeeId,
    this.departmentName,
    this.geofenceStatus,
    required this.isLate,
    required this.lateMinutes,
  });

  final String attendanceId;
  final String attendanceDate;
  final String? checkInTime;
  final String? checkOutTime;
  final double workingHours;
  final String status;
  final String? employeeName;
  final String? employeeId;
  final String? departmentName;
  final String? geofenceStatus;
  final bool isLate;
  final int lateMinutes;

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      attendanceId: asString(json['attendance_id']),
      attendanceDate: asString(json['attendance_date']),
      checkInTime: asNullableString(json['check_in_time']),
      checkOutTime: asNullableString(json['check_out_time']),
      workingHours: asDouble(json['working_hours']),
      status: asString(json['status'], 'Unknown'),
      employeeName: asNullableString(json['employee_name']),
      employeeId: asNullableString(json['employee_id']),
      departmentName: asNullableString(json['department_name']),
      geofenceStatus: asNullableString(json['geofence_status']),
      isLate: asBool(json['is_late']),
      lateMinutes: asInt(json['late_minutes']),
    );
  }
}

class LeaveBalanceItem {
  const LeaveBalanceItem({
    required this.leaveType,
    required this.totalDays,
    required this.usedDays,
  });

  final String leaveType;
  final double totalDays;
  final double usedDays;

  double get remaining =>
      (totalDays - usedDays).clamp(0.0, totalDays).toDouble();

  factory LeaveBalanceItem.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceItem(
      leaveType: asString(json['leave_type']),
      totalDays: asDouble(json['total_days']),
      usedDays: asDouble(json['used_days']),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.mode,
    this.totals,
    this.companies = const [],
    this.headcount,
    this.todayAttendance,
    this.pendingApprovals,
    this.deptBreakdown = const [],
    this.upcomingHolidays = const [],
    this.myToday,
    this.myBalances = const [],
    this.recentAttendance = const [],
  });

  final String mode;
  final DashboardTotals? totals;
  final List<CompanySummary> companies;
  final DashboardHeadcount? headcount;
  final TodayAttendance? todayAttendance;
  final PendingApprovals? pendingApprovals;
  final List<DepartmentCount> deptBreakdown;
  final List<HolidayItem> upcomingHolidays;
  final AttendanceSummary? myToday;
  final List<LeaveBalanceItem> myBalances;
  final List<AttendanceSummary> recentAttendance;

  bool get isSuperAdmin => mode == 'super_admin';

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final myTodayJson = json['myToday'];
    return DashboardData(
      mode: asString(json['mode'], 'company'),
      totals: json['totals'] == null
          ? null
          : DashboardTotals.fromJson(asMap(json['totals'])),
      companies: asMapList(json['companies'])
          .map(CompanySummary.fromJson)
          .toList(),
      headcount: json['headcount'] == null
          ? null
          : DashboardHeadcount.fromJson(asMap(json['headcount'])),
      todayAttendance: json['todayAttendance'] == null
          ? null
          : TodayAttendance.fromJson(asMap(json['todayAttendance'])),
      pendingApprovals: json['pendingApprovals'] == null
          ? null
          : PendingApprovals.fromJson(asMap(json['pendingApprovals'])),
      deptBreakdown: asMapList(json['deptBreakdown'])
          .map(DepartmentCount.fromJson)
          .toList(),
      upcomingHolidays: asMapList(json['upcomingHolidays'])
          .map(HolidayItem.fromJson)
          .toList(),
      myToday: myTodayJson == null
          ? null
          : AttendanceSummary.fromJson(asMap(myTodayJson)),
      myBalances: asMapList(json['myBalances'])
          .map(LeaveBalanceItem.fromJson)
          .toList(),
      recentAttendance: asMapList(json['recentAttendance'])
          .map(AttendanceSummary.fromJson)
          .toList(),
    );
  }
}
