import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import 'package:tapapp_flutter/widgets/Loader.dart';

class FollowingScreen extends StatefulWidget {
  final String userId;
  const FollowingScreen({super.key, required this.userId});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  List<dynamic> following = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await Api.get('/social/following/${widget.userId}',
          headers: await auth.authHeader());
      if (res.statusCode == 200) {
        following = jsonDecode(res.body);
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        error = 'Backend authentication failed. Social features unavailable.';
      } else {
        error = 'Failed to load following: ${res.statusCode}';
      }
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Following')),
        body: const Center(child: JumpingLoader()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Following')),
        body: Center(child: Text(error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: following.isEmpty
          ? const Center(child: Text('Not following anyone'))
          : ListView.builder(
              itemCount: following.length,
              itemBuilder: (context, index) {
                final user = following[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user['fullname'] ?? ''),
                  subtitle: Text('@${user['username']}'),
                  trailing: user['is_following']
                      ? const Text('Following')
                      : ElevatedButton(
                          onPressed: () {}, // TODO: follow/unfollow
                          child: const Text('Follow'),
                        ),
                );
              },
            ),
    );
  }
}
