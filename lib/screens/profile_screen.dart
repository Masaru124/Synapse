import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import 'package:tapapp_flutter/widgets/Loader.dart';
import 'followers_screen.dart';
import 'following_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? profile;
  List<dynamic> links = [];
  bool loading = true;
  String? error;
  int followersCount = 0;
  int followingCount = 0;
  Map<String, dynamic> stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _launchUrl(String url, String platform) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // Log link click
    try {
      final auth = context.read<AuthProvider>();
      await Api.post(
          '/analytics/', {'event_type': 'link_click', 'event_data': platform},
          headers: await auth.authHeader());
    } catch (e) {
      debugPrint('Failed to log link click: $e');
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final p =
          await Api.get('/user/profile', headers: await auth.authHeader());

      print('Profile GET response: ${p.statusCode} - ${p.body}');

      if (p.statusCode == 200) {
        profile = jsonDecode(p.body);

        // Always fetch social links separately to ensure fresh data
        final l = await Api.get('/user/social-links',
            headers: await auth.authHeader());
        print('Social links GET response: ${l.statusCode} - ${l.body}');
        if (l.statusCode == 200) {
          final responseData = jsonDecode(l.body);
          if (responseData is List) {
            links = responseData;
          } else if (responseData is Map && responseData.containsKey('data')) {
            links = responseData['data'];
          }
        }

        // Fetch stats
        final s =
            await Api.get('/analytics/stats', headers: await auth.authHeader());
        print('Stats GET response: ${s.statusCode} - ${s.body}');
        if (s.statusCode == 200) {
          stats = jsonDecode(s.body);
        }

        // Populate followers and following counts
        if (profile != null) {
          followersCount = profile!['followers_count'] ?? 0;
          followingCount = profile!['following_count'] ?? 0;
        }
      } else if (p.statusCode == 401 || p.statusCode == 403) {
        // Backend auth failed, but user is authenticated with Firebase
        // Set up basic profile data from Firebase
        profile = {
          'username': auth.displayName ?? auth.email?.split('@')[0] ?? 'User',
          'email': auth.email,
          'id': auth.uid,
          'followers_count': 0,
          'following_count': 0,
        };
        links = [];
        stats = {};
        followersCount = 0;
        followingCount = 0;
      } else {
        // Other errors
        error = 'Failed to load profile: ${p.statusCode}';
        return;
      }

      links = links
          .where((link) =>
              link != null &&
              link['platform_name'] != null &&
              link['link_url'] != null &&
              link['platform_name'].toString().isNotEmpty &&
              link['link_url'].toString().isNotEmpty)
          .toList();

      error = null;
    } catch (e) {
      error = e.toString();
      links = [];
    }
    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  IconData _getPlatformIcon(String? platform) {
    switch (platform?.toLowerCase()) {
      case 'facebook':
        return Icons.facebook;
      case 'linkedin':
        return Icons.linked_camera;
      case 'github':
        return Icons.code;
      case 'youtube':
        return Icons.play_circle_filled;
      case 'website':
        return Icons.public;
      default:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final colorScheme = theme.colorScheme;
    final auth = context.read<AuthProvider>();

    if (loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const JumpingLoader(),
              const SizedBox(height: 16),
              Text(
                'Loading your profile',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Profile',
            style: TextStyle(color: Colors.white),
          ),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text('Could not load profile',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                Text(error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white60)),
                const SizedBox(height: 24),
                FilledButton(onPressed: _load, child: const Text('Try Again')),
              ],
            ),
          ),
        ),
      );
    }

    if (profile == null) return const SizedBox.shrink();

    final joinedDate = profile!['created_at'] != null
        ? DateFormat.yMMM().format(DateTime.parse(profile!['created_at']))
        : 'N/A';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: "NataSans"),
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.6,
        backgroundColor: Colors.grey[900],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(1),
            bottomLeft: Radius.circular(1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 30, left: 16, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text(
                    "Settings",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: "NataSans",
                    ),
                  ),
                ),
                Divider(height: 1, thickness: 0.5, color: Colors.grey[700]),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    auth.logout();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.redAccent, size: 22),
                        SizedBox(width: 12),
                        Text(
                          "Logout",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + Stats
              Row(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color.fromRGBO(9, 91, 168, 1),
                          Color.fromRGBO(13, 49, 150, 1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStat("Followers", followersCount.toString()),
                        _buildStat("Following", followingCount.toString()),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (profile != null && profile!['id'] != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                FollowersScreen(userId: profile!['id']),
                          ),
                        );
                      }
                    },
                    child: const Text('Followers'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (profile != null && profile!['id'] != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                FollowingScreen(userId: profile!['id']),
                          ),
                        );
                      }
                    },
                    child: const Text('Following'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Name + Username
              Text(
                profile!['fullname'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              if (profile!['username'] != null)
                Text(
                  "@${profile!['username']}",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                  ),
                ),

              const SizedBox(height: 6),

              // Bio
              if (profile!['bio'] != null && profile!['bio'].isNotEmpty)
                Text(
                  profile!['bio'],
                  style: const TextStyle(
                      fontSize: 13, height: 1.3, color: Colors.white70),
                ),

              const SizedBox(height: 6),

              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat(
                      "Link Clicks", (stats['link_click'] ?? 0).toString()),
                  _buildStat(
                      "Profile Views", (stats['profile_view'] ?? 0).toString()),
                  _buildStat("QR Scans", (stats['qr_scan'] ?? 0).toString()),
                ],
              ),

              const SizedBox(height: 6),

              // Joined Date
              Row(
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    "Joined $joinedDate",
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Edit Profile Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: Colors.grey[700]!),
                  ),
                  onPressed: () async {
                    final result = await context.push('/edit');
                    if (result == true) {
                      _load();
                    }
                  },
                  child: const Text(
                    "Edit Profile",
                    style: TextStyle(
                        fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Links Section
              if (links.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: links.map((link) {
                    return InkWell(
                      onTap: () =>
                          _launchUrl(link['link_url'], link['platform_name']),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              _getPlatformIcon(link['platform_name']),
                              color: Colors.blueAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                link['platform_name'] ?? '',
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.white),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildStat(String label, String count) {
  return Column(
    children: [
      Text(
        count,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color.fromARGB(137, 255, 255, 255)),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: const TextStyle(
            fontSize: 13, color: Color.fromARGB(137, 255, 255, 255)),
      ),
    ],
  );
}
