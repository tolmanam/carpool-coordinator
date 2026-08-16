import 'package:flutter/material.dart';

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
                      title: const Text('2. Pickup: Sarah Connor'),
                      subtitle: Text(
                        'Scheduled: 4:40 PM • ETA: ${_delayReported ? '4:50 PM' : '4:40 PM'}',
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
                    onPressed: () {
                      setState(() => _activeDrive = !_activeDrive);
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
                    onPressed: () {
                      setState(() => _delayReported = !_delayReported);
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
