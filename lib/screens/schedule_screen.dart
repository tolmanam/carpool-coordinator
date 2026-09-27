import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import '../services/matrix_service.dart';
import '../services/ical_parser_service.dart';
import '../services/route_optimizer_service.dart';
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
  List<Announcement> _announcements = [];
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
      final anns = await db.getAnnouncements(_activeSchedule!.scheduleId);
      if (mounted) setState(() => _announcements = anns);
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

  void _handleSendAnnouncementDialog() {
    if (_activeSchedule == null) return;

    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool isUrgent = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Broadcast Schedule Announcement'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Announcement Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Message Body',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Urgent Alert / Cancellation'),
                    subtitle: const Text('Dispatches high-priority org.carpool.urgent_alert event'),
                    value: isUrgent,
                    onChanged: (v) {
                      if (v != null) setDialogState(() => isUrgent = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final msg = messageController.text.trim();
                    if (title.isNotEmpty && msg.isNotEmpty) {
                      final matrix = Provider.of<MatrixService>(context, listen: false);
                      await matrix.sendScheduleAnnouncement(
                        _activeSchedule!.scheduleId,
                        title,
                        msg,
                        isUrgent: isUrgent,
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        await _loadData();
                      }
                    }
                  },
                  child: const Text('Broadcast Announcement'),
                ),
              ],
            );
          },
        );
      },
    );
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
      final matchedSignups = _signups.where((s) => s.eventTimestamp == event.startTime).toList();
      final driverSignup = matchedSignups.where((s) => s.role == 'driver').firstOrNull;

      // Check driver booster capacity if booster seat is required
      if (driverSignup != null && childMember.requiresBoosterSeat) {
        final driverMember = _members.firstWhere((m) => m.memberId == driverSignup.memberId, orElse: () => FamilyMember(memberId: '', matrixId: '', name: '', role: 'parent'));
        if (!driverMember.supportsBoosterSeats) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Vehicle does not support required booster seats.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      }

      String equipmentTags = '';
      int boosterCount = childMember.requiresBoosterSeat ? 1 : 0;
      bool reqPin = false;

      if (mounted) {
        final equipController = TextEditingController();
        final dialogRes = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (ctx) {
            int boosterVal = boosterCount;
            bool pinReq = false;
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Ride Details & Logistics'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: equipController,
                        decoration: const InputDecoration(
                          labelText: 'Equipment / Cargo Tags (e.g. gear bag, cello)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Booster Seats Required: '),
                          DropdownButton<int>(
                            value: boosterVal,
                            items: [0, 1, 2, 3]
                                .map((b) => DropdownMenuItem(value: b, child: Text('$b')))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => boosterVal = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Request PIN Verification for Handoff'),
                        subtitle: const Text('Requires driver to verify PIN at pickup/dropoff'),
                        value: pinReq,
                        onChanged: (v) {
                          if (v != null) setDialogState(() => pinReq = v);
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, {
                        'equipment': equipController.text.trim(),
                        'booster': boosterVal,
                        'pin_required': pinReq,
                      }),
                      child: const Text('Confirm Ride Request'),
                    ),
                  ],
                );
              },
            );
          },
        );

        if (dialogRes == null) return;
        equipmentTags = dialogRes['equipment'] as String? ?? '';
        boosterCount = dialogRes['booster'] as int? ?? boosterCount;
        reqPin = dialogRes['pin_required'] as bool? ?? false;
      }

      final status = driverSignup != null ? 'claimed' : 'requested';
      await matrix.sendSignup(
        _activeSchedule!.scheduleId,
        childMember.memberId,
        'rider',
        status,
        event.startTime,
        equipmentTags: equipmentTags,
        boosterCount: boosterCount,
        claimedByDriverId: driverSignup?.memberId ?? '',
        handoffPinRequired: reqPin,
        handoffPin: reqPin ? '1234' : '',
      );
    }

    await _loadData();
  }

  void _claimRideForPassenger(LocalIcalEvent event, Signup passengerSignup) async {
    final matrix = Provider.of<MatrixService>(context, listen: false);
    final parentMember = _members.firstWhere(
      (m) => m.role == 'parent' || m.canDrive,
      orElse: () => FamilyMember(
        memberId: 'parent_${matrix.username}',
        matrixId: matrix.username,
        name: matrix.username,
        role: 'parent',
      ),
    );

    // US-208 Detour Threshold Preview Check
    final family = await Provider.of<DatabaseService>(context, listen: false).getFamily(parentMember.matrixId) ??
        Family(matrixId: parentMember.matrixId, familyName: 'Local Family', latitude: 34.0522, longitude: -118.2437, addressText: 'Home', lastUpdated: 0);

    final driverHome = LocationCoord(latitude: family.latitude, longitude: family.longitude, memberId: parentMember.memberId);
    final dest = LocationCoord(latitude: _activeSchedule?.latitude ?? 34.0415, longitude: _activeSchedule?.longitude ?? -118.4520, memberId: 'dest');
    final candidate = LocationCoord(latitude: family.latitude + 0.01, longitude: family.longitude + 0.01, memberId: passengerSignup.memberId);

    final impact = RouteOptimizerService.calculateDetourImpact(
      driverHome: driverHome,
      destination: dest,
      existingRiders: [],
      candidateRider: candidate,
    );

    final timeDelta = impact['time_delta_minutes'] as int;
    final maxDetour = parentMember.maxDetourMinutes;

    if (mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Route Impact Preview (US-208)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estimated Detour Time: +$timeDelta mins'),
              Text('Driver Max Detour Limit: $maxDetour mins'),
              if (timeDelta > maxDetour) ...[
                const SizedBox(height: 8),
                const Text('Warning: This pickup exceeds your set detour threshold!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Claim Ride')),
          ],
        ),
      );

      if (confirm != true) return;
    }

    await matrix.claimPassengerRide(
      _activeSchedule!.scheduleId,
      event.startTime,
      passengerSignup.memberId,
      parentMember.memberId,
    );
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
      int selectedCapacity = 4;
      if (mounted) {
        final capacityResult = await showDialog<int>(
          context: context,
          builder: (ctx) {
            int capacity = 4;
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Volunteer as Driver'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Specify vehicle seat capacity (excluding driver):'),
                      const SizedBox(height: 12),
                      DropdownButton<int>(
                        value: capacity,
                        isExpanded: true,
                        items: List.generate(8, (index) => index + 1)
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text('$c passenger seats'),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => capacity = val);
                          }
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, capacity),
                      child: const Text('Confirm'),
                    ),
                  ],
                );
              },
            );
          },
        );

        if (capacityResult == null) return; // User cancelled dialog
        selectedCapacity = capacityResult;
      }

      await db.insertSignup(
        Signup(
          id: 'signup_${DateTime.now().millisecondsSinceEpoch}',
          scheduleId: _activeSchedule!.scheduleId,
          eventTimestamp: event.startTime,
          memberId: parentMember.memberId,
          role: 'driver',
          status: 'scheduled',
          seatCapacity: selectedCapacity,
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
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Local Database Synced Offline',
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Commutes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _handleSendAnnouncementDialog,
                  icon: const Icon(Icons.campaign, size: 18),
                  label: const Text('Announce'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // US-309 & US-311 Urgent Announcements / Schedule Alerts Banners
            ..._announcements.map((ann) {
              final isUrgent = ann.isUrgent;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUrgent ? Colors.red.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isUrgent ? Colors.red.shade700 : Colors.blue.shade700),
                ),
                child: Row(
                  children: [
                    Icon(isUrgent ? Icons.warning_amber : Icons.campaign, color: isUrgent ? Colors.red : Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ann.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isUrgent ? Colors.red.shade900 : Colors.blue.shade900,
                            ),
                          ),
                          Text(
                            ann.message,
                            style: TextStyle(fontSize: 12, color: isUrgent ? Colors.red.shade900 : Colors.blue.shade900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            Builder(
              builder: (context) {
                final conflicts = IcalParserService.detectScheduleConflicts(_events);
                if (conflicts.isEmpty) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.amber, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Schedule Conflict Detected!',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Text(
                              '${conflicts.length} overlapping commute event(s) found. Organize carpooling early to ensure all children get a ride.',
                              style: const TextStyle(fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

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
                                Expanded(child: Text(driverName)),
                                if (driverSignup != null) ...[
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      '${riderSignups.where((r) => r.status == 'claimed' || r.claimedByDriverId.isNotEmpty).length}/${driverSignup.seatCapacity} Seats Claimed',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: riderSignups.where((r) => r.status == 'claimed' || r.claimedByDriverId.isNotEmpty).length >= driverSignup.seatCapacity
                                        ? Colors.orange.shade100
                                        : Colors.green.shade100,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.group, size: 18, color: theme.colorScheme.secondary),
                                const SizedBox(width: 8),
                                const Text('Riders: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Expanded(child: Text(riderNames.isNotEmpty ? riderNames : 'No riders registered')),
                              ],
                            ),
                            if (driverSignup != null && isDriving) ...[
                              ...riderSignups.where((r) => r.status == 'requested' || r.claimedByDriverId.isEmpty).map((unclaimedRider) {
                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amber.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_add_alt_1, size: 16, color: Colors.amber),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('Requested Ride (${unclaimedRider.memberId})', style: const TextStyle(fontSize: 12))),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(visualDensity: VisualDensity.compact),
                                        onPressed: () => _claimRideForPassenger(event, unclaimedRider),
                                        child: const Text('Claim Ride', style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            if (riderSignups.any((r) => r.equipmentTags.isNotEmpty || r.boosterCount > 0)) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.work_outline, size: 16, color: Colors.deepOrange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      riderSignups
                                          .where((r) => r.equipmentTags.isNotEmpty || r.boosterCount > 0)
                                          .map((r) => '${r.equipmentTags.isNotEmpty ? "Gear: ${r.equipmentTags}" : ""}${r.boosterCount > 0 ? " [Booster: ${r.boosterCount}]" : ""}')
                                          .join('; '),
                                      style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
