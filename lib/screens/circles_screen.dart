import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import '../services/matrix_service.dart';
import '../models/models.dart';
import '../widgets/empty_state_widget.dart';

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key});

  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> {
  final _circleNameController = TextEditingController();
  final _icalFeedController = TextEditingController();
  final _inviteController = TextEditingController();

  List<Schedule> _circles = [];
  Schedule? _selectedCircle;
  List<FamilyMember> _circleMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCircles();
  }

  Future<void> _loadCircles() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final circles = await db.getSchedules();

    if (mounted) {
      setState(() {
        _circles = circles;
        if (_circles.isNotEmpty) {
          _selectedCircle = _selectedCircle != null && _circles.any((c) => c.scheduleId == _selectedCircle!.scheduleId)
              ? _circles.firstWhere((c) => c.scheduleId == _selectedCircle!.scheduleId)
              : _circles.first;
          _icalFeedController.text = _selectedCircle!.icalFeedUrl;
        } else {
          _selectedCircle = null;
          _icalFeedController.clear();
        }
        _isLoading = false;
      });

      if (_selectedCircle != null) {
        await _loadCircleMembers(_selectedCircle!.scheduleId);
      }
    }
  }

  Future<void> _loadCircleMembers(String scheduleId) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final members = await db.getAllFamilyMembers();
    if (mounted) {
      setState(() {
        _circleMembers = members;
      });
    }
  }

  void _handleCreateCircle() async {
    if (_circleNameController.text.trim().isEmpty) return;
    final matrix = Provider.of<MatrixService>(context, listen: false);
    try {
      final newId = await matrix.createCircle(
        _circleNameController.text.trim(),
        icalFeedUrl: _icalFeedController.text.trim(),
      );
      _circleNameController.clear();
      await _loadCircles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Circle created! Room ID: $newId')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating circle: $e')),
        );
      }
    }
  }

  void _handleSaveIcalFeed() async {
    if (_selectedCircle == null) return;
    final db = Provider.of<DatabaseService>(context, listen: false);

    final updated = Schedule(
      scheduleId: _selectedCircle!.scheduleId,
      title: _selectedCircle!.title,
      icalFeedUrl: _icalFeedController.text.trim(),
      latitude: _selectedCircle!.latitude,
      longitude: _selectedCircle!.longitude,
      addressText: _selectedCircle!.addressText,
      homeserverUrl: _selectedCircle!.homeserverUrl,
    );

    await db.insertSchedule(updated);
    await _loadCircles();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendar feed URL saved!')),
      );
    }
  }

  void _handleInvite() async {
    if (_inviteController.text.trim().isEmpty || _selectedCircle == null) return;
    final matrix = Provider.of<MatrixService>(context, listen: false);
    final input = _inviteController.text.trim();

    if (input.contains('@') && !input.startsWith('@')) {
      // Email invitation -> Generate mailto: link
      final mailtoUrl = matrix.generateEmailInviteLink(
        _selectedCircle!.scheduleId,
        _selectedCircle!.title,
        input,
      );

      _inviteController.clear();
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Send Email Invitation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invitation email generated for $input:'),
                const SizedBox(height: 12),
                SelectableText(
                  mailtoUrl,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Text('Send this mailto link or copy the join URL to send via email.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } else {
      // Matrix ID invitation
      try {
        await matrix.inviteMember(_selectedCircle!.scheduleId, input);
        _inviteController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Matrix room invitation sent to $input!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invite failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Coordination Circles',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (_circles.isEmpty)
            EmptyStateWidget(
              icon: Icons.group_add,
              title: 'No Circles Created',
              description: 'Create a new coordination circle or accept a Matrix room invite to start sharing schedules with other families.',
              buttonText: 'Create Your First Circle',
              onButtonPressed: () {
                _circleNameController.text = 'Neighborhood Carpool Circle';
                _handleCreateCircle();
              },
            )
          else ...[
            DropdownButtonFormField<String>(
              value: _selectedCircle?.scheduleId,
              decoration: const InputDecoration(
                labelText: 'Active Selected Circle',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shield),
              ),
              items: _circles.map((c) {
                return DropdownMenuItem<String>(
                  value: c.scheduleId,
                  child: Text(c.title, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCircle = _circles.firstWhere((c) => c.scheduleId == val);
                    _icalFeedController.text = _selectedCircle!.icalFeedUrl;
                  });
                  _loadCircleMembers(_selectedCircle!.scheduleId);
                }
              },
            ),
            const SizedBox(height: 16),

            if (_selectedCircle != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Circle iCal Calendar Feed',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _icalFeedController,
                        decoration: const InputDecoration(
                          labelText: 'iCal Feed URL (.ics)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                          hintText: 'https://example.com/calendar.ics',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _handleSaveIcalFeed,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Feed URL'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Circle Participants',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_circleMembers.isEmpty)
                        const Text('No members registered in local cache yet.')
                      else
                        ..._circleMembers.map((m) => ListTile(
                              leading: CircleAvatar(
                                child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?'),
                              ),
                              title: Text(m.name),
                              subtitle: Text('Role: ${m.role} • Matrix: ${m.matrixId}'),
                            )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite Member to Circle',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _inviteController,
                        decoration: const InputDecoration(
                          labelText: 'Matrix ID (@user:server) or Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_add),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _handleInvite,
                          icon: const Icon(Icons.send),
                          label: const Text('Send Invitation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Standalone Circle',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _circleNameController,
                    decoration: const InputDecoration(
                      labelText: 'Circle Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleCreateCircle,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Standalone Circle'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
