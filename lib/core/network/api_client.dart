import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart' show sha256;
import 'package:http/http.dart' as http;
import '../constants/constants.dart';

// ── EXCEPTION ────────────────────────────────────────────────
class ApiEx implements Exception {
  final String message;
  final int?   code;
  const ApiEx(this.message, {this.code});
  @override String toString() => message;
}

// ── API CLIENT ────────────────────────────────────────────────
class Api {
  static final Api _i = Api._();
  factory Api() => _i;
  Api._();

  int?    _driverId;

  void setSession(int id) => _driverId = id;
  void clearSession()     => _driverId = null;

  Map<String, String> get _headers => {
    'apikey':        Cfg.supabaseKey,
    'Authorization': 'Bearer ${Cfg.supabaseKey}',
    'Content-Type':  'application/json',
    'Prefer':        'return=representation',
    if (_driverId != null) 'x-driver-id': _driverId!.toString(),
  };

  String _qs(Map<String, String> p) {
    if (p.isEmpty) return '';
    final parts = p.entries.map((e) {
      final m = RegExp(r'^((?:eq|neq|lt|lte|gt|gte|in|is|like|ilike|cs|cd|not)\.)(.+)$')
          .firstMatch(e.value);
      return m != null
          ? '${Uri.encodeComponent(e.key)}=${m.group(1)}${Uri.encodeComponent(m.group(2)!)}'
          : '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}';
    }).toList();
    return '?${parts.join("&")}';
  }

  Future<dynamic> _fetch(String method, String path,
      {Map<String, String> params = const {}, Map<String, dynamic>? body}) async {
    final isRpc = path.startsWith('/rpc/');
    final uri   = Uri.parse('${Cfg.restBase}$path${isRpc ? "" : _qs(params)}');
    http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
        case 'POST':
        print(uri);
print(jsonEncode(body));
          res = await http.post(uri, headers: _headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 20));
        case 'PATCH':
          res = await http.patch(uri, headers: _headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 20));
        default:
          throw const ApiEx('Unknown method');
      }
    } on TimeoutException {
      throw const ApiEx('Request timed out');
    } catch (e) {
      if (e is ApiEx) rethrow;
      throw ApiEx('Network error: $e');
    }
    if (res.statusCode == 204) return null;
    final decoded = jsonDecode(res.body);
    print("STATUS = ${res.statusCode}");
print("BODY   = ${res.body}");
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final m = decoded is Map
          ? (decoded['message'] ?? decoded['hint'] ?? decoded['error'] ?? 'Error')
          : 'Request failed (${res.statusCode})';
      throw ApiEx(
          m.toString()
              .replaceAll(RegExp(r'^ERROR:\s*', caseSensitive: false), '')
              .replaceAll(RegExp(r'\s*CONTEXT:.*', dotAll: true), '')
              .trim(),
          code: res.statusCode);
    }
    return decoded;
  }

  Future<dynamic> get(String table, {Map<String, String> p = const {}}) =>
      _fetch('GET', '/$table', params: p);
  Future<dynamic> post(String table, Map<String, dynamic> data) =>
      _fetch('POST', '/$table', body: data);
  Future<dynamic> patch(String table, Map<String, String> filter, Map<String, dynamic> data) =>
      _fetch('PATCH', '/$table', params: filter, body: data);
  Future<dynamic> rpc(String fn, Map<String, dynamic> args) =>
      _fetch('POST', '/rpc/$fn', body: args);

  static String sha256hex(String s) => sha256.convert(utf8.encode(s)).toString();

  Future<String> uploadImage(File file) async {
    // Cloudinary unsigned upload — NO Authorization header needed
    final req = http.MultipartRequest('POST', Uri.parse(Cfg.cloudUrl));
    req.fields['upload_preset'] = Cfg.uploadPreset;
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    // Explicitly do NOT add the Supabase auth headers
    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      final body = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      throw ApiEx('Upload failed (${res.statusCode}): $body');
    }
    final json = jsonDecode(res.body) as Map;
    return json['secure_url'] as String;
  }
}
