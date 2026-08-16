import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/matrix_service.dart';
import '../services/database_service.dart';
import '../models/models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _familyNameController = TextEditingController();
  final Set<String> _userRoles = {'Parent', 'Driver'};
  String _notificationSound = 'Default';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final matrix = Provider.of<MatrixService>(context, listen: false);

    final userMatrixId = matrix.username.startsWith('@') ? matrix.username : '@${matrix.username}:matrix.org';
    final family = await db.getFamily(userMatrixId);

    if (family != null) {
      _familyNameController.text = family.familyName;
    } else {
      _familyNameController.text = 'The ${matrix.username.replaceAll('@', '').split(':').first} Family';
    }

    final sound = await db.getSetting('notification_sound');
    if (sound != null) {
      _notificationSound = sound;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleRole(String role) {
    setState(() {
      if (_userRoles.contains(role)) {
        if (_userRoles.length > 1) _userRoles.remove(role);
      } else {
        _userRoles.add(role);
      }
    });
  }

  void _saveFamilyDetails() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final matrix = Provider.of<MatrixService>(context, listen: false);

    final userMatrixId = matrix.username.startsWith('@') ? matrix.username : '@${matrix.username}:matrix.org';
    final name = _familyNameController.text.trim();

    if (name.isNotEmpty) {
      await db.insertFamily(Family(
        matrixId: userMatrixId,
        familyName: name,
        latitude: 34.0194,
        longitude: -118.4912,
        addressText: '734 Ocean Avenue, Santa Monica, CA',
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      ));

      await db.setSetting('notification_sound', _notificationSound);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Family details and settings saved to database!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matrix = Provider.of<MatrixService>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. System Configuration',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Signed in as: ${matrix.username}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Homeserver: ${matrix.homeserver}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  const Divider(height: 24),

                  Text('Notification Sound', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Default', label: Text('Default')),
                      ButtonSegment(value: 'Chime', label: Text('Chime')),
                      ButtonSegment(value: 'Mute', label: Text('Mute')),
                    ],
                    selected: {_notificationSound},
                    onSelectionChanged: (val) {
                      setState(() => _notificationSound = val.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            '2. Profile Configuration',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Roles (Multi-Select)', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Parent', 'Driver', 'Participant'].map((role) {
                      final selected = _userRoles.contains(role);
                      return FilterChip(
                        selected: selected,
                        label: Text(role),
                        onSelected: (_) => _toggleRole(role),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            '3. Family Group Configuration',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _familyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Family Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.home),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _saveFamilyDetails,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Family Details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => matrix.logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Logout Session'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
