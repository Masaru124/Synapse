import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  User? _user;
  bool _loading = true;

  bool get loading => _loading;
  bool get loggedIn => _user != null;
  String? get email => _user?.email;
  String? get uid => _user?.uid;
  String? get displayName => _user?.displayName;

  // 🔹 Configure GoogleSignIn with your Web Client ID
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        "670967196705-o10lt1tmdom0attqg51j68dd7v0ojabe.apps.googleusercontent.com",
  );

  AuthProvider() {
    _init();
  }

  void _init() {
    // 🔹 Listen to Firebase authentication state
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      _user = user;
      _loading = false;

      if (user != null) {
        final idToken = await user.getIdToken(true);
        await _storage.write(key: 'token', value: idToken);
        await _storage.write(key: 'uid', value: user.uid);
        await _storage.write(key: 'email', value: user.email ?? '');
      } else {
        await _storage.delete(key: 'token');
        await _storage.delete(key: 'uid');
        await _storage.delete(key: 'email');
      }

      notifyListeners();
    });
  }

  /// 🔹 Sync user with backend after Firebase authentication
  Future<void> _syncWithBackend({String? username}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken(true);
      final response = await http.post(
        Uri.parse("http://10.0.2.2:8000/api/auth/google-login"),
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({"id_token": idToken, "username": username}),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Synced with backend successfully");
      } else {
        debugPrint("⚠️ Backend sync failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("⚠️ Backend sync error: $e");
    }
  }

  /// 🔹 Register with Email and Password (Firebase)
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String username,
    String? fullname,
  }) async {
    try {
      // Create user in Firebase
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user == null) {
        return AuthResult.error(
          message: 'Registration failed: user not created',
        );
      }

      // Send email verification
      await user.sendEmailVerification();

      // Sync with backend (optional - doesn't affect Firebase auth success)
      await _syncWithBackend(username: username);

      return AuthResult.success(user: user);
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase registration error: ${e.code} - ${e.message}");
      String message = 'Registration failed';
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'weak-password':
          message = 'Password is too weak';
          break;
        case 'operation-not-allowed':
          message = 'Email/password sign-in is not enabled';
          break;
      }
      return AuthResult.error(message: message);
    } catch (e) {
      debugPrint("Registration error: $e");
      return AuthResult.error(message: 'Registration failed: $e');
    }
  }

  /// 🔹 Login with Email and Password (Firebase)
  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      if (user == null) {
        return AuthResult.error(message: 'Login failed: user not found');
      }

      // Check if email is verified
      if (!user.emailVerified) {
        await user.sendEmailVerification();
        return AuthResult.error(
          message:
              'Please verify your email. A new verification email has been sent.',
          requiresVerification: true,
        );
      }

      // Sync with backend (optional - doesn't affect Firebase auth success)
      await _syncWithBackend();

      return AuthResult.success(user: user);
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase login error: ${e.code} - ${e.message}");
      String message = 'Login failed';
      switch (e.code) {
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        case 'user-not-found':
          message = 'No account found with this email';
          break;
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'operation-not-allowed':
          message = 'Email/password sign-in is not enabled';
          break;
      }
      return AuthResult.error(message: message);
    } catch (e) {
      debugPrint("Login error: $e");
      return AuthResult.error(message: 'Login failed: $e');
    }
  }

  /// 🔹 Reset Password (Firebase)
  Future<bool> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      debugPrint("Password reset email sent to $email");
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("Password reset error: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      debugPrint("Password reset error: $e");
      return false;
    }
  }

  /// 🔹 Google Sign-In
  Future<bool> loginWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCred.user;
      if (user == null) return false;

      // Sync with backend (optional - doesn't affect Firebase auth success)
      try {
        await _syncWithBackend();
      } catch (e) {
        debugPrint("Backend sync failed, but login successful: $e");
      }

      return true;
    } catch (e) {
      debugPrint("Google login error: $e");
      return false;
    }
  }

  /// 🔹 Logout
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
  }

  /// 🔹 Auth Header for API calls
  Future<Map<String, String>> authHeader() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken(true) : null;
    return {'Authorization': 'Bearer ${token ?? ''}'};
  }

  String parseError(String body, [int? status]) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map && parsed['detail'] != null) {
        return parsed['detail'].toString();
      }
    } catch (_) {}
    if (status == 400) return 'Invalid data';
    if (status == 500) return 'Server error. Please try again later.';
    return body;
  }
}

/// 🔹 Auth Result class for handling auth operations
class AuthResult {
  final bool success;
  final User? user;
  final String message;
  final bool requiresVerification;

  AuthResult({
    required this.success,
    this.user,
    required this.message,
    this.requiresVerification = false,
  });

  factory AuthResult.success({required User user}) {
    return AuthResult(success: true, user: user, message: 'Success');
  }

  factory AuthResult.error({
    required String message,
    bool requiresVerification = false,
  }) {
    return AuthResult(
      success: false,
      user: null,
      message: message,
      requiresVerification: requiresVerification,
    );
  }
}
