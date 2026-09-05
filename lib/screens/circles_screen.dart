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
  final _orgNameController = TextEditingController();
  final _orgIcalController = TextEditingController();

  final _circleNameController = TextEditingController();
  final _circleAddressController = TextEditingController();

  final _inviteController = TextEditingController();
  final _chatMessageController = TextEditingController();

  List<Organization> _organizations = [];
  Organization? _selectedOrg;

  List<CarpoolCircle> _carpoolCircles = [];
  CarpoolCircle? _selectedCircle;

  List<FamilyMember> _allFamilyMembers = [];
  List<OrganizationParticipant> _orgParticipants = [];
  List<ChatMessage> _chatMessages = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = Provider.of<DatabaseService>(context, listen: false);

    final orgs = await db.getOrganizations();
    final familyMembers = await db.getAllFamilyMembers();

    if (mounted) {
      setState(() {
        _organizations = orgs;
        _allFamilyMembers = familyMembers;

        if (_organizations.isNotEmpty) {
          _selectedOrg = _selectedOrg != null && _organizations.any((o) => o.orgId == _selectedOrg!.orgId)
              ? _organizations.firstWhere((o) => o.orgId == _selectedOrg!.orgId)
              : _organizations.first;
          _orgIcalController.text = _selectedOrg!.icalFeedUrl;
        } else {
          _selectedOrg = null;
          _orgIcalController.clear();
        }
        _isLoading = false;
      });

      if (_selectedOrg != null) {
        await _loadOrgDetails(_selectedOrg!.orgId);
      }
    }
  }

  Future<void> _loadOrgDetails(String orgId) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final circles = await db.getCarpoolCircles(orgId);
    final participants = await db.getOrgParticipants(orgId);

    if (mounted) {
      setState(() {
        _carpoolCircles = circles;
        _orgParticipants = participants;

        if (_carpoolCircles.isNotEmpty) {
          _selectedCircle = _selectedCircle != null && _carpoolCircles.any((c) => c.circleId == _selectedCircle!.circleId)
              ? _carpoolCircles.firstWhere((c) => c.circleId == _selectedCircle!.circleId)
              : _carpoolCircles.first;
        } else {
          _selectedCircle = null;
        }
      });

      final activeRoomId = _selectedCircle?.circleId ?? _selectedOrg?.orgId ?? '';
      if (activeRoomId.isNotEmpty) {
        await _loadChatMessages(activeRoomId);
      }
    }
  }

  Future<void> _loadChatMessages(String roomId) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final msgs = await db.getChatMessages(roomId);
    if (mounted) {
      setState(() {
        _chatMessages = msgs;
      });
    }
  }

  void _handleCreateOrg() async {
    final name = _orgNameController.text.trim();
    if (name.isEmpty) return;

    final matrix = Provider.of<MatrixService>(context, listen: false);
    try {
      final org = await matrix.createOrganization(
        name,
        _orgIcalController.text.trim(),
      );
      _orgNameController.clear();
      _orgIcalController.clear();
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created Organization "${org.name}"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating organization: $e')),
        );
      }
    }
  }

  void _handleCreateCircle() async {
    if (_selectedOrg == null) return;
    final name = _circleNameController.text.trim();
    if (name.isEmpty) return;

    final matrix = Provider.of<MatrixService>(context, listen: false);
    try {
      final circle = await matrix.createCircleForOrg(
        _selectedOrg!.orgId,
        name,
        _circleAddressController.text.trim(),
      );

      _circleNameController.clear();
      _circleAddressController.clear();
      await _loadOrgDetails(_selectedOrg!.orgId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created Carpool Circle "${circle.name}"!')),
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

  void _handleToggleParticipant(String memberId) async {
    if (_selectedOrg == null) return;
    final db = Provider.of<DatabaseService>(context, listen: false);

    final isParticipant = _orgParticipants.any((p) => p.memberId == memberId);
    if (isParticipant) {
      await db.deleteOrgParticipant(_selectedOrg!.orgId, memberId);
    } else {
      await db.insertOrgParticipant(OrganizationParticipant(
        id: '${_selectedOrg!.orgId}_$memberId',
        orgId: _selectedOrg!.orgId,
        memberId: memberId,
        circleId: _selectedCircle?.circleId ?? '',
      ));
    }

    await _loadOrgDetails(_selectedOrg!.orgId);
  }

  void _handleSendChatMessage() async {
    final text = _chatMessageController.text.trim();
    final roomId = _selectedCircle?.circleId ?? _selectedOrg?.orgId ?? '';
    if (text.isEmpty || roomId.isEmpty) return;

    final matrix = Provider.of<MatrixService>(context, listen: false);
    final senderName = matrix.username.isNotEmpty ? matrix.username : 'Family Admin';

    await matrix.sendChatMessage(roomId, text, senderName);
    _chatMessageController.clear();
    await _loadChatMessages(roomId);
  }

  void _handleInvite() async {
    final roomId = _selectedCircle?.circleId ?? _selectedOrg?.orgId ?? '';
    final roomTitle = _selectedCircle?.name ?? _selectedOrg?.name ?? 'Carpool Group';
    if (_inviteController.text.trim().isEmpty || roomId.isEmpty) return;

    final matrix = Provider.of<MatrixService>(context, listen: false);
    final input = _inviteController.text.trim();

    if (input.contains('@') && !input.startsWith('@')) {
      // Email invitation -> Generate mailto: link
      final mailtoUrl = matrix.generateEmailInviteLink(
        roomId,
        roomTitle,
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
        await matrix.inviteMember(roomId, input);
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
            'Organizations & Carpool Circles',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (_organizations.isEmpty)
            EmptyStateWidget(
              icon: Icons.corporate_fare,
              title: 'No Organizations Found',
              description: 'Create an Organization for your sports team, gymnastics club, or social group to manage shared schedules and carpool circles.',
              buttonText: 'Create Your First Organization',
              onButtonPressed: () {
                _orgNameController.text = 'Westside Sports Team';
                _orgIcalController.text = 'https://sports-club.org/calendars/u10.ics';
                _handleCreateOrg();
              },
            )
          else ...[
            // 1. Select Active Organization
            DropdownButtonFormField<String>(
              value: _selectedOrg?.orgId,
              decoration: const InputDecoration(
                labelText: 'Active Organization (Shared Schedule)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.domain),
              ),
              items: _organizations.map((o) {
                return DropdownMenuItem<String>(
                  value: o.orgId,
                  child: Text(o.name, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedOrg = _organizations.firstWhere((o) => o.orgId == val);
                    _orgIcalController.text = _selectedOrg!.icalFeedUrl;
                  });
                  _loadOrgDetails(_selectedOrg!.orgId);
                }
              },
            ),
            const SizedBox(height: 16),

            if (_selectedOrg != null) ...[
              // Organization Schedule Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedOrg!.name} Schedule',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('iCal URL: ${_selectedOrg!.icalFeedUrl.isNotEmpty ? _selectedOrg!.icalFeedUrl : "None set"}',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Organization Participants (Individual Family Members)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Organization Participants (My Family)',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_allFamilyMembers.isEmpty)
                        const Text('No family members added yet. Add family members in Settings.')
                      else
                        ..._allFamilyMembers.map((member) {
                          final isParticipant = _orgParticipants.any((p) => p.memberId == member.memberId);
                          return CheckboxListTile(
                            title: Text(member.name),
                            subtitle: Text('${member.isAdult ? "Adult" : "Child"} • ${member.canDrive ? "Driver" : "Rider"}'),
                            value: isParticipant,
                            onChanged: (_) => _handleToggleParticipant(member.memberId),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Carpool Circles (Subdivisions)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carpool Circle Subdivisions',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_carpoolCircles.isEmpty)
                        const Text('No carpool circles created under this organization yet.')
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedCircle?.circleId,
                          decoration: const InputDecoration(
                            labelText: 'Active Carpool Circle',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.group),
                          ),
                          items: _carpoolCircles.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.circleId,
                              child: Text(c.name, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCircle = _carpoolCircles.firstWhere((c) => c.circleId == val);
                              });
                              _loadChatMessages(_selectedCircle!.circleId);
                            }
                          },
                        ),
                      const SizedBox(height: 12),
                      Text('Create Circle Subdivision:', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _circleNameController,
                        decoration: const InputDecoration(
                          labelText: 'Circle Name (e.g. Northside Carpool)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.subdirectory_arrow_right),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _circleAddressController,
                        decoration: const InputDecoration(
                          labelText: 'Pickup Address (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _handleCreateCircle,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Carpool Circle Subdivision'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. In-App Group Messaging / Chat
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.chat, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Group Chat (${_selectedCircle != null ? _selectedCircle!.name : _selectedOrg!.name})',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 160,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _chatMessages.isEmpty
                            ? const Center(child: Text('No messages in this chat group yet.'))
                            : ListView.builder(
                                itemCount: _chatMessages.length,
                                itemBuilder: (ctx, idx) {
                                  final msg = _chatMessages[idx];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(color: theme.colorScheme.onSurface),
                                        children: [
                                          TextSpan(
                                            text: '${msg.senderName}: ',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          TextSpan(text: msg.content),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatMessageController,
                              decoration: const InputDecoration(
                                hintText: 'Type group message...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _handleSendChatMessage,
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Send Invite
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite Family to Organization / Circle',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
          // Create New Organization Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Organization',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _orgNameController,
                    decoration: const InputDecoration(
                      labelText: 'Organization Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _orgIcalController,
                    decoration: const InputDecoration(
                      labelText: 'Shared iCal Feed URL',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleCreateOrg,
                      icon: const Icon(Icons.add_business),
                      label: const Text('Create Organization'),
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
