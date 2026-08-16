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
  final _inviteController = TextEditingController();
  List<Schedule> _circles = [];
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
        _isLoading = false;
      });
    }
  }

  void _handleCreateCircle() async {
    if (_circleNameController.text.trim().isEmpty) return;
    final matrix = Provider.of<MatrixService>(context, listen: false);
    await matrix.createCircle(_circleNameController.text.trim());
    _circleNameController.clear();
    await _loadCircles();
  }

  void _handleInvite() async {
    if (_inviteController.text.trim().isEmpty || _circles.isEmpty) return;
    final matrix = Provider.of<MatrixService>(context, listen: false);
    await matrix.inviteMember(_circles.first.scheduleId, _inviteController.text.trim());
    _inviteController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matrix invitation sent!')),
      );
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
          else
            ..._circles.map((c) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.shield, color: theme.colorScheme.primary),
                    ),
                    title: Text(
                      c.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('End-to-End Encrypted • Matrix Room Active'),
                    trailing: const Icon(Icons.check_circle, color: Colors.green),
                  ),
                )),

          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Circle',
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
                      label: const Text('Create Circle'),
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
                    'Invite Member to Circle',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inviteController,
                    decoration: const InputDecoration(
                      labelText: 'Matrix ID or Email',
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
                      label: const Text('Send Matrix Invitation'),
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
      ),
    );
  }
}
