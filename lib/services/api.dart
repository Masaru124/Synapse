import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

// class Api {
//   /// Automatically use correct host for emulator vs. device
//   static String get baseUrl {
//     if (Platform.isAndroid) {
//       return 'http://10.0.2.2:8000/api'; // Android emulator
//     } else if (Platform.isIOS) {
//       return 'http://localhost:8000/api'; // iOS simulator
//     } else {
//       return 'http://127.0.0.1:8000/api'; // fallback for desktop
//     }
//   }

//   /// 🔑 Get Firebase ID Token
//   static Future<String?> _getToken() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) return await user.getIdToken();
//     return null;
//   }

//   /// 🔑 Build headers (with token if logged in)
//   static Future<Map<String, String>> _headers(
//       [Map<String, String>? extra]) async {
//     final token = await _getToken();
//     final h = <String, String>{
//       'Content-Type': 'application/json',
//       ...?extra,
//     };
//     if (token != null) h['Authorization'] = 'Bearer $token';
//     return h;
//   }

//   /// GET
//   static Future<http.Response> get(String path,
//       {Map<String, String>? headers}) async {
//     final uri = Uri.parse('$baseUrl$path');
//     final h = await _headers(headers);
//     return http.get(uri, headers: h);
//   }

//   /// POST (JSON)
//   static Future<http.Response> post(String path, Map<String, dynamic> data,
//       {Map<String, String>? headers}) async {
//     final uri = Uri.parse('$baseUrl$path');
//     final h = await _headers(headers);
//     return http.post(uri, headers: h, body: jsonEncode(data));
//   }

//   /// POST (Form-encoded)
//   static Future<http.Response> postForm(String path, Map<String, String> body,
//       {Map<String, String>? headers}) async {
//     final uri = Uri.parse('$baseUrl$path');
//     final h = await _headers(headers);
//     return http.post(uri, headers: h, body: body);
//   }

//   /// PUT
//   static Future<http.Response> put(String path, Map<String, dynamic> data,
//       {Map<String, String>? headers}) async {
//     final uri = Uri.parse('$baseUrl$path');
//     final h = await _headers(headers);
//     return http.put(uri, headers: h, body: jsonEncode(data));
//   }

//   /// DELETE
//   static Future<http.Response> delete(String path,
//       {Map<String, String>? headers}) async {
//     final uri = Uri.parse('$baseUrl$path');
//     final h = await _headers(headers);
//     return http.delete(uri, headers: h);
//   }
// }

class Api {
  static String get baseUrl {
    if (Platform.isAndroid)
      return 'https://tapcard-backend-gkql.onrender.com/api';
    if (Platform.isIOS) return 'https://tapcard-backend-gkql.onrender.com/api';
    return 'https://tapcard-backend-gkql.onrender.com/api';
  }

  static Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await user.getIdToken(true); // force refresh
    }
    return null;
  }

  static Future<Map<String, String>> _headers(
      [Map<String, String>? extra]) async {
    final token = await _getToken();
    final h = <String, String>{'Content-Type': 'application/json', ...?extra};
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  static Future<http.Response> get(String path,
      {Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl${path.startsWith('/') ? path : '/$path'}');
    final h = await _headers(headers);
    return http.get(uri, headers: h).timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> post(String path, Map<String, dynamic> data,
      {Map<String, String>? headers, bool useAuth = true}) async {
    // Ensure path is prefixed with a slash exactly once
    final uri = Uri.parse('$baseUrl${path.startsWith('/') ? path : '/$path'}');
    final h = useAuth
        ? await _headers(headers)
        : <String, String>{'Content-Type': 'application/json', ...?headers};

    // Enforce a 15-second timeout on the POST request
    return http
        .post(uri, headers: h, body: jsonEncode(data))
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> put(String path, Map<String, dynamic> data,
      {Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl${path.startsWith('/') ? path : '/$path'}');
    final h = await _headers(headers);
    return http.put(uri, headers: h, body: jsonEncode(data));
  }

  static Future<http.Response> delete(String path,
      {Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl$path');
    final h = await _headers(headers);
    return http.delete(uri, headers: h);
  }
}
