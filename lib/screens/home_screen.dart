import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
// import 'package:intl/intl.dart';
import 'package:tapapp_flutter/widgets/Loader.dart';

import '../providers/auth_provider.dart';
import '../services/api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? profile;
  bool loading = true;
  String? error;

  final GlobalKey _qrKey = GlobalKey(); // for QR capture

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final res =
          await Api.get('/user/profile', headers: await auth.authHeader());
      if (res.statusCode == 200) {
        profile = jsonDecode(res.body) as Map<String, dynamic>;
      } else if (res.statusCode == 404) {
        // User not found in backend - profile needs to be created
        error = 'Profile not set up yet. Please complete your profile setup.';
        // Don't logout - user is authenticated with Firebase
      } else if (res.statusCode == 401 || res.statusCode == 403) {
        // Auth error - backend can't verify token, but user is authenticated with Firebase
        error =
            'Backend authentication failed, but you are logged in with Firebase.';
        // Don't logout - user is authenticated with Firebase
      } else {
        error = 'Failed to load profile: ${res.statusCode}';
        // Don't logout for other server errors
      }
    } catch (e) {
      error = e.toString();
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    if (loading) return const Center(child: JumpingLoader());

    // Use Firebase user data if backend profile failed
    final username = profile?['username'] ??
        auth.displayName ??
        auth.email?.split('@')[0] ??
        'User';
    final id = profile?['id'] ?? profile?['user_id'] ?? auth.uid ?? '';
    final qrValue = 'https://synapseeee.vercel.app/u/$id';

    if (error != null && profile == null) {
      // Show Firebase-based UI when backend fails
      return Scaffold(
        backgroundColor: isDarkMode
            ? Colors.grey[900]
            : const ui.Color.fromARGB(255, 0, 0, 0),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Synapse',
            style: TextStyle(
              fontFamily: "Cursive",
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: isDarkMode
                  ? Colors.white
                  : const ui.Color.fromARGB(255, 255, 255, 255),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Greeting
              Text(
                'Hello @$username',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Logged in with Firebase',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 32),
              // QR Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: RepaintBoundary(
                  key: _qrKey,
                  child: QrImageView(
                    data: qrValue,
                    version: QrVersions.auto,
                    size: MediaQuery.of(context).size.width * 0.6,
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Colors.white,
                    ),
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: ui.Color.fromRGBO(0, 96, 250, 1),
                    ),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 8),
              Text(
                'Your Digital Identity',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 40),
              // Share Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const ui.Color.fromRGBO(0, 96, 250, 1),
                    foregroundColor:
                        const ui.Color.fromARGB(255, 255, 255, 255),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  onPressed: () =>
                      Share.share('Connect with me on Synapse: $qrValue'),
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text(
                    'Share QR Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (profile == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor:
          isDarkMode ? Colors.grey[900] : const ui.Color.fromARGB(255, 0, 0, 0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Synapse',
          style: TextStyle(
            fontFamily: "Cursive",
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: isDarkMode
                ? Colors.white
                : const ui.Color.fromARGB(255, 255, 255, 255),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Greeting
            Text(
              'Hello @$username',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Instruction
            Text(
              'Scan to connect',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),

            // QR Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: RepaintBoundary(
                key: _qrKey,
                child: QrImageView(
                  data: qrValue,
                  version: QrVersions.auto,
                  size: MediaQuery.of(context).size.width * 0.6,
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Colors.white,
                  ),
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: ui.Color.fromRGBO(0, 96, 250, 1),
                  ),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 8),
            Text(
              'Your Digital Identity',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 40),

            // Share Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const ui.Color.fromRGBO(0, 96, 250, 1),
                  foregroundColor: const ui.Color.fromARGB(
                      255, 255, 255, 255), // Icon & text color
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50), // fully rounded
                  ),
                ),
                onPressed: () =>
                    Share.share('Connect with me on Synapse: $qrValue'),
                icon: const Icon(Icons.share, size: 20),
                label: const Text(
                  'Share QR Code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
