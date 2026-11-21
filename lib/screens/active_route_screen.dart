import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import '../services/matrix_service.dart';
import '../services/background_streaming_service.dart';
import '../services/route_optimizer_service.dart';
import '../models/models.dart';
import '../widgets/empty_state_widget.dart';

class ActiveRouteScreen extends StatefulWidget {
  final String scheduleId;
  final int eventTimestamp;

  const ActiveRouteScreen({
    super.key,
    required this.scheduleId,
    required this.eventTimestamp,
  });

  @override
  State<ActiveRouteScreen> createState() => _ActiveRouteScreenState();
}

class _ActiveRouteScreenState extends State<ActiveRouteScreen> {
  // --- Loading state ---
  bool _isLoading = true;
  String? _loadError;

  // --- Route data ---
  Schedule? _schedule;
  List<RouteWaypoint> _waypoints = [];
  List<Signup> _riderSignups = [];
  Map<String, FamilyMember> _memberById = {};
  Signup? _driverSignup;
  LocationCoord? _driverHome;

  // --- Drive control state ---
  bool _activeDrive = false;
  bool _delayReported = false;
  final Set<String> _checkedInMembers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRouteData());
  }

  Future<void> _loadRouteData() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final matrixService = Provider.of<MatrixService>(context, listen: false);

    try {
      // 1. Get all signups for this event occurrence
      final allSignups = await dbService.getSignupsByEvent(
        widget.scheduleId,
        widget.eventTimestamp,
      );

      // 2. Find driver signup
      final driverSignup = allSignups.firstWhere(
        (s) => s.role == 'driver' && s.status != 'canceled',
        orElse: () => Signup(
          id: '',
          scheduleId: widget.scheduleId,
          eventTimestamp: widget.eventTimestamp,
          memberId: '',
          role: 'driver',
          status: 'canceled',
        ),
      );

      final driverMemberId = driverSignup.memberId;

      // 3. Filter rider signups for this driver
      final riderSignups = allSignups
          .where((s) =>
              s.role == 'rider' &&
              s.status != 'canceled' &&
              (s.claimedByDriverId == driverMemberId ||
                  s.claimedByDriverId.isEmpty))
          .toList();

      // 4. Build memberId → FamilyMember lookup
      final allMembers = await dbService.getAllFamilyMembers();
      final memberById = {for (final m in allMembers) m.memberId: m};

      // 5. Resolve each rider's pickup location
      final List<LocationCoord> riderCoords = [];
      for (final signup in riderSignups) {
        final member = memberById[signup.memberId];
        if (member == null) continue;
        final family = await dbService.getFamily(member.matrixId);
        if (family == null) continue;
        riderCoords.add(RouteOptimizerService.resolveRiderLocation(
          member: member,
          family: family,
          eventTimestamp: widget.eventTimestamp,
        ));
      }

      // 6. Resolve driver's home location
      final driverFamily = await dbService.getFamily(matrixService.username);
      LocationCoord? driverHome;
      String? loadError;

      if (driverFamily == null ||
          (driverFamily.latitude == 0.0 && driverFamily.longitude == 0.0)) {
        loadError = 'missing_driver_coords';
      } else {
        driverHome = LocationCoord(
          latitude: driverFamily.latitude,
          longitude: driverFamily.longitude,
          memberId: driverMemberId,
        );
      }

      // 7. Find the schedule
      final schedules = await dbService.getSchedules();
      final schedule = schedules.cast<Schedule?>().firstWhere(
        (s) => s?.scheduleId == widget.scheduleId,
        orElse: () => null,
      );

      // 8. Build waypoints (only if driver coords are valid)
      List<RouteWaypoint> waypoints = [];
      if (driverHome != null && schedule != null && riderSignups.isNotEmpty) {
        final destination = LocationCoord(
          latitude: schedule.latitude,
          longitude: schedule.longitude,
          memberId: 'destination',
        );
        waypoints = RouteOptimizerService.solveOptimalRoute(
          driverHome,
          destination,
          riderCoords,
          widget.eventTimestamp,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = loadError;
          _schedule = schedule;
          _waypoints = waypoints;
          _riderSignups = riderSignups;
          _memberById = memberById;
          _driverSignup = driverSignup.id.isEmpty ? null : driverSignup;
          _driverHome = driverHome;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = 'load_failed';
        });
      }
    }
  }

  // --- Map helpers ---

  List<LatLng> _waypointLatLngs() {
    return _waypoints
        .map((wp) => LatLng(wp.latitude, wp.longitude))
        .toList();
  }

  Polyline _buildRoutePolyline() {
    return Polyline(
      points: _waypointLatLngs(),
      color: Theme.of(context).colorScheme.primary,
      strokeWidth: 4.0,
    );
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];
    for (int i = 0; i < _waypoints.length; i++) {
      final wp = _waypoints[i];
      final latLng = LatLng(wp.latitude, wp.longitude);

      if (wp.type == 'driver_start') {
        markers.add(Marker(
          point: latLng,
          width: 36,
          height: 36,
          child: const Icon(Icons.directions_car, color: Colors.blue, size: 28),
        ));
      } else if (wp.type == 'pickup') {
        final member = _memberById[wp.memberId];
        final initials = member != null && member.name.isNotEmpty
            ? member.name.trim().split(' ').map((w) => w[0]).take(2).join()
            : '?';
        markers.add(Marker(
          point: latLng,
          width: 36,
          height: 36,
          child: CircleAvatar(
            backgroundColor: Colors.indigo,
            radius: 16,
            child: Text(
              initials,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ));
      } else if (wp.type == 'destination') {
        markers.add(Marker(
          point: latLng,
          width: 36,
          height: 36,
          child: const Icon(Icons.flag, color: Colors.green, size: 28),
        ));
      }
    }
    return markers;
  }

  // --- PIN dialog ---

  Future<bool> _showPinDialog(String expectedPin) async {
    final pinController = TextEditingController();
    bool? result;

    result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('PIN Verification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Parent requested PIN verification at pickup.'),
              const SizedBox(height: 12),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Enter PIN'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true), // bypass allowed
              child: const Text('Bypass / Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                if (pinController.text.trim() == expectedPin) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid PIN')),
                  );
                  Navigator.pop(ctx, false);
                }
              },
              child: const Text('Verify PIN'),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  // --- Emergency medical dialog ---

  void _showEmergencyMedicalDialog(String memberId) {
    final member = _memberById[memberId];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.medical_services, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergency Contact & Medical'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Passenger: ${member?.name ?? 'Unknown'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (member?.emergencyContact.isNotEmpty == true)
              Text('• Emergency Contact: ${member!.emergencyContact}'),
            if (member?.medicalNotes.isNotEmpty == true)
              Text('• Medical Alert: ${member!.medicalNotes}'),
            if (member?.requiresBoosterSeat == true)
              const Text('• Booster Seat: Required'),
            const Divider(height: 20),
            const Text(
              'Restricted Access (US-310): For active drive session only.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- UI helpers ---

  String _formatTime(int ms) {
    return DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  Widget _buildRiderCard(Signup signup, int stopIndex) {
    final member = _memberById[signup.memberId];
    final name = member?.name ?? 'Unknown';
    final boardedKey = '${signup.memberId}_pickup';
    final deliveredKey = '${signup.memberId}_dropoff';
    final boarded = _checkedInMembers.contains(boardedKey);
    final delivered = _checkedInMembers.contains(deliveredKey);

    // Find matching waypoint for ETA
    final wp = _waypoints.cast<RouteWaypoint?>().firstWhere(
      (w) => w?.memberId == signup.memberId && w?.type == 'pickup',
      orElse: () => null,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  radius: 16,
                  child: Text(
                    '$stopIndex',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pickup: $name',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (wp != null)
                        Text(
                          'ETA: ${_formatTime(wp.estimatedTime)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (member != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  if (member.requiresBoosterSeat)
                    Chip(
                      avatar: const Icon(Icons.airline_seat_recline_extra, size: 14),
                      label: const Text('Booster Seat', style: TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  if (member.medicalNotes.isNotEmpty)
                    Tooltip(
                      message: member.medicalNotes,
                      child: Chip(
                        avatar: const Icon(Icons.medical_services, size: 14, color: Colors.red),
                        label: const Text('Medical Note', style: TextStyle(fontSize: 10, color: Colors.red)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.red.shade50,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: boarded
                      ? null
                      : () async {
                          bool verified = true;
                          if (signup.handoffPinRequired && signup.handoffPin.isNotEmpty) {
                            verified = await _showPinDialog(signup.handoffPin);
                          }
                          if (!verified) return;
                          final matrixService = Provider.of<MatrixService>(context, listen: false);
                          await matrixService.sendAttendanceCheckin(
                            widget.scheduleId,
                            widget.eventTimestamp,
                            signup.memberId,
                            signup.handoffPinRequired ? 'pickup_pin_verified' : 'pickup',
                            matrixService.username,
                          );
                          if (mounted) {
                            setState(() => _checkedInMembers.add(boardedKey));
                          }
                        },
                  icon: Icon(
                    boarded ? Icons.check_box : Icons.check_circle_outline,
                    size: 16,
                    color: boarded ? Colors.green : null,
                  ),
                  label: Text(boarded ? 'Pickup Recorded' : 'Child Boarded'),
                ),
                OutlinedButton.icon(
                  onPressed: delivered
                      ? null
                      : () async {
                          final matrixService = Provider.of<MatrixService>(context, listen: false);
                          await matrixService.sendAttendanceCheckin(
                            widget.scheduleId,
                            widget.eventTimestamp,
                            signup.memberId,
                            'dropoff',
                            matrixService.username,
                          );
                          if (mounted) {
                            setState(() => _checkedInMembers.add(deliveredKey));
                          }
                        },
                  icon: Icon(
                    delivered ? Icons.check_box : Icons.task_alt,
                    size: 16,
                    color: delivered ? Colors.green : null,
                  ),
                  label: Text(delivered ? 'Dropoff Recorded' : 'Child Delivered'),
                ),
                TextButton.icon(
                  onPressed: () => _showEmergencyMedicalDialog(signup.memberId),
                  icon: const Icon(Icons.contact_phone, size: 16, color: Colors.red),
                  label: const Text('Emergency Info', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Carpool Route')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Empty state — no riders for this occurrence
    if (_riderSignups.isEmpty && _loadError == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Active Carpool Route'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: EmptyStateWidget(
          icon: Icons.directions_car_outlined,
          title: 'No riders for this carpool',
          description: 'No active rider signups found for this occurrence.',
          buttonText: 'Back to Schedule',
          onButtonPressed: () => Navigator.pop(context),
        ),
      );
    }

    // --- Map widget ---
    final latLngs = _waypointLatLngs();
    Widget mapWidget;
    if (latLngs.length >= 2) {
      mapWidget = SizedBox(
        height: 240,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(latLngs),
                padding: const EdgeInsets.all(40),
              ),
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'org.carpool.coordinator',
                errorTileCallback: (tile, error, stackTrace) {},
              ),
              PolylineLayer(polylines: [_buildRoutePolyline()]),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
        ),
      );
    } else {
      // Fallback placeholder when no valid waypoints (e.g., missing driver coords)
      mapWidget = Container(
        height: 240,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                'Route unavailable',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    // --- Itinerary list items ---
    int stopIndex = 1;
    final itineraryWidgets = <Widget>[];

    // Driver start
    final driverStartWp = _waypoints.cast<RouteWaypoint?>().firstWhere(
      (w) => w?.type == 'driver_start',
      orElse: () => null,
    );
    itineraryWidgets.add(ListTile(
      leading: const Icon(Icons.directions_car, color: Colors.blue),
      title: Text('${stopIndex++}. Start: Driver (You)'),
      subtitle: driverStartWp != null
          ? Text('Departs: ${_formatTime(driverStartWp.estimatedTime)}')
          : null,
    ));

    // Rider pickups
    for (final signup in _riderSignups) {
      itineraryWidgets.add(_buildRiderCard(signup, stopIndex++));
    }

    // Destination
    final destWp = _waypoints.cast<RouteWaypoint?>().firstWhere(
      (w) => w?.type == 'destination',
      orElse: () => null,
    );
    itineraryWidgets.add(ListTile(
      leading: const Icon(Icons.flag, color: Colors.green),
      title: Text('${stopIndex++}. Destination: ${_schedule?.addressText ?? 'Event Location'}'),
      subtitle: destWp != null ? Text('ETA: ${_formatTime(destWp.estimatedTime)}') : null,
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Carpool Route'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- Missing driver coords warning banner ---
            if (_loadError == 'missing_driver_coords')
              MaterialBanner(
                content: const Text('Your home address is not set. Route calculation unavailable.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go to Settings'),
                  ),
                ],
              ),

            // --- Map ---
            mapWidget,
            const SizedBox(height: 16),

            // --- Route summary card ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_schedule != null)
                      Text(
                        'Destination: ${_schedule!.addressText}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    if (destWp != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Estimated Arrival: ${_formatTime(destWp.estimatedTime)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const Divider(height: 24),
                    ...itineraryWidgets,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Drive control buttons ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final newDriveState = !_activeDrive;
                      setState(() => _activeDrive = newDriveState);

                      try {
                        final streaming = Provider.of<BackgroundStreamingService>(context, listen: false);
                        if (newDriveState) {
                          await streaming.startBackgroundLocationStreaming(
                            widget.scheduleId,
                            initialLat: _driverHome?.latitude ?? 0.0,
                            initialLng: _driverHome?.longitude ?? 0.0,
                          );
                        } else {
                          await streaming.stopBackgroundLocationStreaming();
                        }
                      } catch (_) {
                        final matrix = Provider.of<MatrixService>(context, listen: false);
                        if (newDriveState) {
                          await matrix.sendLocation(
                            widget.scheduleId,
                            _driverHome?.latitude ?? 0.0,
                            _driverHome?.longitude ?? 0.0,
                            _riderSignups
                                .map((s) => {'member_id': s.memberId})
                                .toList(),
                          );
                        }
                      }
                    },
                    icon: Icon(_activeDrive ? Icons.stop : Icons.play_arrow),
                    label: Text(_activeDrive ? 'Stop Drive' : 'Start Drive'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _activeDrive ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final newDelayState = !_delayReported;
                      setState(() => _delayReported = newDelayState);
                      if (newDelayState) {
                        final matrix = Provider.of<MatrixService>(context, listen: false);
                        await matrix.sendAlert(
                          widget.scheduleId,
                          'delay_10m',
                          'Driver reported a 10-minute traffic delay.',
                        );
                      }
                    },
                    icon: const Icon(Icons.warning_amber),
                    label: Text(_delayReported ? 'Delay Dispatched' : 'Report 10m Delay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            // --- GPS streaming status indicator ---
            if (_activeDrive) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, color: Colors.red, size: 10),
                    SizedBox(width: 8),
                    Text(
                      'Streaming GPS coordinates to Matrix Room...',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
