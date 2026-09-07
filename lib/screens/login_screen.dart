import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/matrix_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController(text: '@alice:matrix.org');
  final _passwordController = TextEditingController(text: 'password123');
  final _homeserverController = TextEditingController(text: 'https://matrix.org');
  bool _isLoading = false;

  void _handleLogin() async {
    final matrixService = Provider.of<MatrixService>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      await matrixService.login(
        _usernameController.text,
        _passwordController.text,
        homeserverUrl: _homeserverController.text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSSOLogin() async {
    final matrixService = Provider.of<MatrixService>(context, listen: false);
    final homeserverUrl = _homeserverController.text;
    setState(() => _isLoading = true);

    try {
      final flowsData = await matrixService.getLoginFlows(homeserverUrl: homeserverUrl);
      final List<dynamic> flows = flowsData['flows'] ?? [];

      Map<String, dynamic>? ssoFlow;
      for (final flow in flows) {
        if (flow is Map<String, dynamic> && flow['type'] == 'm.login.sso') {
          ssoFlow = flow;
          break;
        }
      }

      final List<dynamic> identityProviders = ssoFlow?['identity_providers'] ?? [];

      if (!mounted) return;
      setState(() => _isLoading = false);

      final tokenController = TextEditingController();

      showDialog(
        context: context,
        builder: (dialogCtx) {
          String? selectedIdpId = identityProviders.isNotEmpty
              ? identityProviders.first['id'] as String?
              : null;

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final redirectUrl = matrixService.getSsoRedirectUrl(
                homeserverUrl: homeserverUrl,
                idpId: selectedIdpId,
              );

              return AlertDialog(
                title: const Text('SSO / OIDC Authentication'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (identityProviders.isNotEmpty) ...[
                        const Text('Choose Identity Provider:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedIdpId,
                          items: identityProviders.map<DropdownMenuItem<String>>((idp) {
                            return DropdownMenuItem<String>(
                              value: idp['id'] as String?,
                              child: Text(idp['name'] as String? ?? idp['id'] as String? ?? 'SSO Provider'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedIdpId = val;
                            });
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Text('1. Open SSO Redirect URL:'),
                      const SizedBox(height: 4),
                      SelectableText(
                        redirectUrl,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                      ),
                      const SizedBox(height: 16),
                      const Text('2. After authenticating, enter your SSO Token:'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tokenController,
                        decoration: const InputDecoration(
                          labelText: 'SSO Login Token',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.key),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final token = tokenController.text.trim();
                      if (token.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid SSO token')),
                        );
                        return;
                      }
                      Navigator.pop(dialogCtx);
                      setState(() => _isLoading = true);
                      try {
                        await matrixService.loginWithToken(
                          token,
                          homeserverUrl: homeserverUrl,
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('SSO Token Login failed: $e')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                    child: const Text('Sign In with Token'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to retrieve SSO login flows: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matrixService = Provider.of<MatrixService>(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Carpool Coordinator',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'Decentralized & Encrypted Group Commutes',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    TextField(
                      controller: _homeserverController,
                      decoration: const InputDecoration(
                        labelText: 'Homeserver URL',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.dns),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username or Matrix ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleLogin,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Sign In with Matrix'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleSSOLogin,
                      icon: const Icon(Icons.security),
                      label: const Text('Sign In with SSO / OIDC'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
