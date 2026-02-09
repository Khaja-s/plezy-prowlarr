import 'package:dio/dio.dart';
import '../models/qbit_torrent.dart';

/// Client for interacting with qBittorrent Web API
class QBitClient {
  final QBitConfig config;
  final Dio _dio;
  String? _sid; // Session ID cookie

  QBitClient({required this.config})
      : _dio = Dio(BaseOptions(
          baseUrl: config.serverUrl.endsWith('/')
              ? config.serverUrl.substring(0, config.serverUrl.length - 1)
              : config.serverUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  /// Login to qBittorrent (required for most operations)
  Future<bool> login() async {
    try {
      final response = await _dio.post(
        '/api/v2/auth/login',
        data: FormData.fromMap({
          'username': config.username ?? 'admin',
          'password': config.password ?? '',
        }),
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data == 'Ok.') {
        // Extract SID cookie
        final cookies = response.headers['set-cookie'];
        if (cookies != null) {
          for (final cookie in cookies) {
            if (cookie.startsWith('SID=')) {
              _sid = cookie.split(';').first;
              break;
            }
          }
        }
        return true;
      }

      // Try without auth (if no auth required)
      return await _testNoAuth();
    } catch (e) {
      return false;
    }
  }

  Future<bool> _testNoAuth() async {
    try {
      final response = await _dio.get('/api/v2/app/version');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get auth headers
  Options get _authOptions {
    return Options(
      headers: _sid != null ? {'Cookie': _sid} : null,
    );
  }

  /// Test connection to qBittorrent
  Future<bool> testConnection() async {
    try {
      // Try login first
      if (config.username != null && config.password != null) {
        return await login();
      }
      // Or just test version endpoint
      final response = await _dio.get('/api/v2/app/version');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get all torrents
  Future<List<QBitTorrent>> getTorrents({String? filter}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (filter != null) {
        queryParams['filter'] = filter;
      }

      final response = await _dio.get(
        '/api/v2/torrents/info',
        queryParameters: queryParams,
        options: _authOptions,
      );

      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((json) => QBitTorrent.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to get torrents: $e');
    }
  }

  /// Pause a torrent
  Future<bool> pauseTorrent(String hash) async {
    try {
      final response = await _dio.post(
        '/api/v2/torrents/pause',
        data: FormData.fromMap({'hashes': hash}),
        options: _authOptions,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Resume a torrent
  Future<bool> resumeTorrent(String hash) async {
    try {
      final response = await _dio.post(
        '/api/v2/torrents/resume',
        data: FormData.fromMap({'hashes': hash}),
        options: _authOptions,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Delete a torrent
  Future<bool> deleteTorrent(String hash, {bool deleteFiles = false}) async {
    try {
      final response = await _dio.post(
        '/api/v2/torrents/delete',
        data: FormData.fromMap({
          'hashes': hash,
          'deleteFiles': deleteFiles.toString(),
        }),
        options: _authOptions,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get transfer info (global speeds)
  Future<Map<String, dynamic>?> getTransferInfo() async {
    try {
      final response = await _dio.get(
        '/api/v2/transfer/info',
        options: _authOptions,
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
