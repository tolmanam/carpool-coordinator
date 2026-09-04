import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import '../services/matrix_service.dart';
import '../models/models.dart';
import '../widgets/empty_state_widget.dart';
import 'active_route_screen.dart';
import 'onboarding_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isLoading = true;
  List<LocalIcalEvent> _events = [];
  List<Signup> _signups = [];
  List<FamilyMember> _members = [];
  Schedule? _activeSchedule;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = Provider.of<DatabaseService>(context, listen: false);

    final schedules = await db.getSchedules();
    List<LocalIcalEvent> events = [];
    List<Signup> signups = [];

    if (schedules.isNotEmpty) {
      _activeSchedule = schedules.first;
      events = await db.getIcalEvents(_activeSchedule!.scheduleId);
      signups = await db.getSignups(_activeSchedule!.scheduleId);
    } else {
      _activeSchedule = null;
    }

    final members = await db.getAllFamilyMembers();

    if (mounted) {
      setState(() {
        _events = events;
        _signups = signups;
        _members = members;
        _isLoading = false;
      });
    }
  }

  void _showOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(
          onCompleted: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _toggleRide(LocalIcalEvent event) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final matrix = Provider.of<MatrixService>(context, listen: false);

    final childMember = _members.firstWhere(
      (m) => m.role == 'child',
      orElse: () => FamilyMember(
        memberId: 'child_${matrix.username}',
        matrixId: matrix.username,
        name: 'Alex',
        role: 'child',
      ),
    );

    final existingRiderSignup = _signups.any(
      (s) =>
          s.eventTimestamp == event.startTime &&
          s.memberId == childMember.memberId &&
          s.role == 'rider',
    );

    if (existingRiderSignup) {
      await db.deleteSignup(_activeSchedule!.scheduleId, event.startTime, childMember.memberId);
    } else {
      await db.insertSignup(
        Signup(
          id: 'signup_${DateTime.now().millisecondsSinceEpoch}',
          scheduleId: _activeSchedule!.scheduleId,
          eventTimestamp: event.startTime,
          memberId: childMember.memberId,
          role: 'rider',
          status: 'scheduled',
        ),
      );
    }

    await _loadData();
  }

  void _toggleDrive(LocalIcalEvent event) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final matrix = Provider.of<MatrixService>(context, listen: false);

    final parentMember = _members.firstWhere(
      (m) => m.role == 'parent',
      orElse: () => FamilyMember(
        memberId: 'parent_${matrix.username}',
        matrixId: matrix.username,
        name: matrix.username,
        role: 'parent',
      ),
    );

    final existingDriverSignup = _signups.any(
      (s) =>
          s.eventTimestamp == event.startTime &&
          s.memberId == parentMember.memberId &&
          s.role == 'driver',
    );

    if (existingDriverSignup) {
      await db.deleteSignup(_activeSchedule!.scheduleId, event.startTime, parentMember.memberId);
    } else {
      await db.insertSignup(
        Signup(
          id: 'signup_${DateTime.now().millisecondsSinceEpoch}',
          scheduleId: _activeSchedule!.scheduleId,
          eventTimestamp: event.startTime,
          memberId: parentMember.memberId,
          role: 'driver',
          status: 'scheduled',
        ),
      );
    }

    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matrix = Provider.of<MatrixService>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_events.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.calendar_month,
        title: 'No Commutes Scheduled',
        description: 'Sync an iCal feed from your school or club to start coordinating rides.',
        buttonText: 'Sync iCal Feed',
        onButtonPressed: _loadData,
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    matrix.isOffline ? Icons.wifi_off : Icons.check_circle_outline,
                    color: matrix.isOffline ? Colors.orange : Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      matrix.isOffline ? 'Offline Mode (Cached Data)' : 'Local Database Synced Offline',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, size: 20),
                    onPressed: _showOnboarding,
                    tooltip: 'App Guide',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Upcoming Commutes',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            ..._events.map((event) {
              final startDt = DateTime.fromMillisecondsSinceEpoch(event.startTime);
              final endDt = DateTime.fromMillisecondsSinceEpoch(event.endTime);

              final timeStr =
                  '${DateFormat('EEE, MMM d').format(startDt)}, ${DateFormat('jm').format(startDt)} - ${DateFormat('jm').format(endDt)}';

              final matchedSignups = _signups.where((s) => s.eventTimestamp == event.startTime).toList();

              final driverSignup = matchedSignups.where((s) => s.role == 'driver').firstOrNull;
              final riderSignups = matchedSignups.where((s) => s.role == 'rider').toList();

              final parentMember = _members.firstWhere(
                (m) => m.role == 'parent',
                orElse: () => FamilyMember(
                  memberId: 'parent_${matrix.username}',
                  matrixId: matrix.username,
                  name: matrix.username,
                  role: 'parent',
                ),
              );

              final childMember = _members.firstWhere(
                (m) => m.role == 'child',
                orElse: () => FamilyMember(
                  memberId: 'child_${matrix.username}',
                  matrixId: matrix.username,
                  name: 'Alex',
                  role: 'child',
                ),
              );

              final isDriving = driverSignup?.memberId == parentMember.memberId;
              final isRiding = riderSignups.any((r) => r.memberId == childMember.memberId);

              final driverName = driverSignup != null
                  ? (driverSignup.memberId == parentMember.memberId ? 'You' : 'Assigned Driver')
                  : 'No driver assigned yet';

              final riderNames = riderSignups.map((r) => r.memberId == childMember.memberId ? 'You' : 'Passenger').join(', ');

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Divider(height: 24),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.directions_car, size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                const Text('Driver: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(driverName),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.group, size: 18, color: theme.colorScheme.secondary),
                                const SizedBox(width: 8),
                                const Text('Riders: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(riderNames.isNotEmpty ? riderNames : 'No riders registered'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: FilterChip(
                              selected: isRiding,
                              label: Text(isRiding ? 'Registered Ride' : 'Ride'),
                              avatar: Icon(isRiding ? Icons.check : Icons.child_care, size: 18),
                              onSelected: (_) => _toggleRide(event),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilterChip(
                              selected: isDriving,
                              label: Text(isDriving ? 'Driving Route' : 'Drive'),
                              avatar: Icon(isDriving ? Icons.check : Icons.time_to_leave, size: 18),
                              onSelected: (_) => _toggleDrive(event),
                            ),
                          ),
                        ],
                      ),

                      if (isDriving) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ActiveRouteScreen(
                                    scheduleId: _activeSchedule!.scheduleId,
                                    eventTimestamp: event.startTime,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.navigation),
                            label: const Text('Start Driving Route'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
