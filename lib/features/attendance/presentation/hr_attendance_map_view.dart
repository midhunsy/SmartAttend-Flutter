import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/geo_utils.dart';
import '../data/attendance_repository.dart';
import '../data/models/attendance_models.dart';
import 'widgets/attendance_map_view.dart';
import 'widgets/attendance_widgets.dart';

class HRAttendanceMapView extends ConsumerStatefulWidget {
  const HRAttendanceMapView({super.key});

  @override
  ConsumerState<HRAttendanceMapView> createState() =>
      _HRAttendanceMapViewState();
}

class _HRAttendanceMapViewState extends ConsumerState<HRAttendanceMapView> {
  late String _date;
  late Future<EmployeeMapData> _mapFuture;
  String? _departmentId;
  String? _employeeRecordId;
  String? _status;

  @override
  void initState() {
    super.initState();
    _date = currentDate();
    _mapFuture = _load();
  }

  Future<EmployeeMapData> _load() {
    return ref
        .read(attendanceRepositoryProvider)
        .loadEmployeeMap(
          date: _date,
          departmentId: _departmentId,
          employeeRecordId: _employeeRecordId,
          status: _status,
        );
  }

  void _reload() {
    setState(() {
      _mapFuture = _load();
    });
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 2),
      lastDate: DateTime(initial.year + 1),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = '${_pad(picked.year)}-${_pad(picked.month)}-${_pad(picked.day)}';
      _mapFuture = _load();
    });
  }

  void _showMarkerDetails(EmployeeMapMarker marker) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        marker.employeeName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    StatusChip(label: marker.status),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoTile(
                      label: 'Employee ID',
                      value: marker.employeeId,
                      mono: true,
                    ),
                    InfoTile(label: 'Date', value: marker.attendanceDate),
                    InfoTile(
                      label: 'Check-in',
                      value: formatLocalTime(marker.checkInTime),
                    ),
                    InfoTile(
                      label: 'Check-out',
                      value: formatLocalTime(marker.checkOutTime),
                    ),
                    InfoTile(
                      label: 'Check-in GPS',
                      value: formatCoordinatePair(
                        marker.latitude,
                        marker.longitude,
                      ),
                      mono: true,
                    ),
                    InfoTile(
                      label: 'Accuracy',
                      value: formatAccuracy(marker.accuracyMeters),
                    ),
                    InfoTile(
                      label: 'Distance',
                      value: _distance(marker.distanceMeters),
                    ),
                    InfoTile(
                      label: 'Geofence',
                      value: marker.geofenceStatus ?? 'Unavailable',
                    ),
                  ],
                ),
                if (marker.assignedOffice != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Assigned office: ${marker.assignedOffice}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (marker.checkOutGeofenceStatus != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    marker.checkOutGeofenceStatus!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeMapData>(
      future: _mapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(_message(snapshot.error)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, filterBox) {
                // Phones: full-width filters, refresh beside the last one.
                final narrow = filterBox.maxWidth < 520;
                final full = filterBox.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: narrow ? full : null,
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.date_range_rounded),
                        label: Text(_date),
                      ),
                    ),
                    SizedBox(
                      width: narrow ? full : 190,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _departmentId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Department',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All departments'),
                          ),
                          ...data.filterOptions.departments.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _departmentId = value;
                            _employeeRecordId = null;
                            _mapFuture = _load();
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: narrow ? full : 210,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _employeeRecordId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Employee',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All employees'),
                          ),
                          ...data.filterOptions.employees.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item.employeeRecordId,
                              child: Text(item.employeeName),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _employeeRecordId = value;
                            _mapFuture = _load();
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: narrow ? full - 58 : 160,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _status,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All statuses'),
                          ),
                          ...data.filterOptions.statuses.map(
                            (item) => DropdownMenuItem<String?>(
                              value: item,
                              child: Text(item),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _status = value;
                            _mapFuture = _load();
                          });
                        },
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: 'Refresh map',
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              '${data.scope == 'company' ? 'Company-wide' : 'Team-scoped'} view '
              '· ${data.markers.length} check-in location${data.markers.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            AttendanceMapView(
              employeeMarkers: data.markers,
              height: 380,
              onEmployeeTap: _showMarkerDetails,
            ),
            if (data.history.isNotEmpty) ...[
              const SizedBox(height: 18),
              SectionCard(
                title: 'Selected employee history',
                subtitle: 'Up to 180 days of attendance records',
                icon: Icons.history_rounded,
                child: Column(
                  children: data.history.take(20).map((item) {
                    return ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: Text('${item.attendanceDate} · ${item.status}'),
                      subtitle: Text(
                        '${formatLocalTime(item.checkInTime)} → ${formatLocalTime(item.checkOutTime)}'
                        '${item.assignedOffice == null ? '' : ' · ${item.assignedOffice}'}',
                      ),
                      trailing: StatusChip(
                        label: item.geofenceStatus ?? 'Unavailable',
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String _distance(double? value) {
    if (value == null) return '—';
    return '${value.round()}m';
  }

  String _message(Object? error) {
    final text = error?.toString() ?? 'Unable to load attendance map.';
    return text.startsWith('Exception:') ? text.substring(10) : text;
  }

  String _pad(int value) => value.toString().padLeft(2, '0');
}
