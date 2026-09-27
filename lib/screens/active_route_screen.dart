import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/matrix_service.dart';

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
  bool _activeDrive = false;
  bool _delayReported = false;
  int _etaMinutes = 25;
  final Set<String> _checkedInMembers = {};

  void _showEmergencyMedicalDialog() {
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Passenger: Sarah Connor', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• Emergency Contact: John Connor (555-0199)'),
            Text('• Medical Alert: Severe Peanut Allergy (EpiPen in backpack)'),
            Text('• Booster Seat: Required'),
            Divider(height: 20),
            Text('Restricted Access (US-310): Decrypted exclusively for active drive session.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 48, color: theme.colorScheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        'Interactive Live Map Route',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_activeDrive)
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
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
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Arrival: ${_delayReported ? _etaMinutes + 10 : _etaMinutes} mins',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Destination: Clover Park Field 2',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Divider(height: 24),

                    const ListTile(
                      leading: Icon(Icons.directions_car, color: Colors.blue),
                      title: Text('1. Start: Driver (You)'),
                      subtitle: Text('Scheduled: 4:30 PM • ETA: 4:30 PM'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.indigo),
                      title: Row(
                        children: [
                          const Text('2. Pickup: Sarah Connor'),
                          const SizedBox(width: 8),
                          Chip(
                            avatar: const Icon(Icons.airline_seat_recline_extra, size: 14),
                            label: const Text('Booster Seat', style: TextStyle(fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Medical: Peanut Allergy',
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
                      subtitle: Text(
                        'Scheduled: 4:40 PM • ETA: ${_delayReported ? '4:50 PM' : '4:40 PM'}',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final matrix = Provider.of<MatrixService>(context, listen: false);
                                  await matrix.sendAttendanceCheckin(
                                    widget.scheduleId,
                                    widget.eventTimestamp,
                                    'child_sarah',
                                    'pickup',
                                    matrix.username,
                                  );
                                  setState(() => _checkedInMembers.add('child_sarah_pickup'));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Attendance Check-in Recorded: Sarah Boarded (Pickup)')),
                                    );
                                  }
                                },
                                icon: Icon(
                                  _checkedInMembers.contains('child_sarah_pickup') ? Icons.check_box : Icons.check_circle_outline,
                                  size: 16,
                                  color: _checkedInMembers.contains('child_sarah_pickup') ? Colors.green : null,
                                ),
                                label: Text(_checkedInMembers.contains('child_sarah_pickup') ? 'Pickup Recorded' : 'Child Boarded'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final matrix = Provider.of<MatrixService>(context, listen: false);
                                  await matrix.sendAttendanceCheckin(
                                    widget.scheduleId,
                                    widget.eventTimestamp,
                                    'child_sarah',
                                    'dropoff',
                                    matrix.username,
                                  );
                                  setState(() => _checkedInMembers.add('child_sarah_dropoff'));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Attendance Check-in Recorded: Sarah Delivered (Drop-off)')),
                                    );
                                  }
                                },
                                icon: Icon(
                                  _checkedInMembers.contains('child_sarah_dropoff') ? Icons.check_box : Icons.task_alt,
                                  size: 16,
                                  color: _checkedInMembers.contains('child_sarah_dropoff') ? Colors.green : null,
                                ),
                                label: Text(_checkedInMembers.contains('child_sarah_dropoff') ? 'Dropoff Recorded' : 'Child Delivered'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // US-310 Dynamic Emergency Contact Access button
                          TextButton.icon(
                            onPressed: _showEmergencyMedicalDialog,
                            icon: const Icon(Icons.contact_phone, size: 16, color: Colors.red),
                            label: const Text('View Driver Emergency & Medical Info', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.flag, color: Colors.green),
                      title: const Text('3. Destination: Clover Park Field 2'),
                      subtitle: Text(
                        'Scheduled: 5:00 PM • ETA: ${_delayReported ? '5:10 PM' : '5:00 PM'}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final matrix = Provider.of<MatrixService>(context, listen: false);
                      final newDriveState = !_activeDrive;
                      setState(() => _activeDrive = newDriveState);

                      if (newDriveState) {
                        await matrix.sendLocation(
                          widget.scheduleId,
                          34.0415,
                          -118.4520,
                          [
                            {'member_id': 'child_1', 'eta_minutes': 15},
                          ],
                        );
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
                      final matrix = Provider.of<MatrixService>(context, listen: false);
                      final newDelayState = !_delayReported;
                      setState(() => _delayReported = newDelayState);

                      if (newDelayState) {
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
          ],
        ),
      ),
    );
  }
}
