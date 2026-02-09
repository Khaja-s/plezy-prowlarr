import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/qbit_torrent.dart';
import '../utils/app_logger.dart';

/// Client for interacting with qBittorrent Web API
class QBitClient {
  final QBitConfig config;
  final Dio _dio;
  String? _sidCookie; // Session ID cookie

  QBitClient({required this.config})
      : _dio = Dio(BaseOptions(
          baseUrl: config.serverUrl.endsWith('/')
              ? config.serverUrl.substring(0, config.serverUrl.length - 1)
              : config.serverUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          validateStatus: (status) => status != null && status < 500,
        ));

  /// Login to qBittorrent and store session cookie
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
        ),
      );

      if (response.statusCode == 200 && response.data == 'Ok.') {
        // Extract SID cookie from response headers
        final cookies = response.headers['set-cookie'];
        if (cookies != null) {
          for (final cookie in cookies) {
            if (cookie.startsWith('SID=')) {
              _sidCookie = cookie.split(';').first;
              appLogger.d('qBit login successful, got SID cookie');
              return true;
            }
          }
        }
        // Some versions don't use SID, login was still successful
        appLogger.d('qBit login successful (no SID cookie)');
        return true;
      }
      
      appLogger.w('qBit login failed: ${response.data}');
      return false;
    } catch (e) {
      appLogger.e('qBit login error', error: e);
      return false;
    }
  }

  /// Get request options with auth cookie
  Options get _authOptions {
    return Options(
      headers: _sidCookie != null ? {'Cookie': _sidCookie} : null,
    );
  }

  /// Ensure we're logged in before making API calls
  Future<bool> _ensureLoggedIn() async {
    if (_sidCookie != null) return true;
    return await login();
  }

  /// Test connection to qBittorrent
  Future<bool> testConnection() async {
    try {
      // First try login
      final loginSuccess = await login();
      if (!loginSuccess) return false;
      
      // Then verify we can get torrents
      final response = await _dio.get(
        '/api/v2/torrents/info',
        options: _authOptions,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      appLogger.e('qBit connection test failed', error: e);
      return false;
    }
  }

  /// Get all torrents
  Future<List<QBitTorrent>> getTorrents({String? filter}) async {
    final loggedIn = await _ensureLoggedIn();
    if (!loggedIn) {
      throw Exception('Failed to login to qBittorrent');
    }
    
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
      
      // Session expired? Try re-login
      if (response.statusCode == 403) {
        _sidCookie = null;
        return getTorrents(filter: filter);
      }
      
      throw Exception('Failed to get torrents: ${response.statusCode}');
    } catch (e) {
      appLogger.e('qBit getTorrents error', error: e);
      rethrow;
    }
  }

  /// Pause a torrent
  Future<bool> pauseTorrent(String hash) async {
    final loggedIn = await _ensureLoggedIn();
    if (!loggedIn) return false;
    
    try {
      final response = await _dio.post(
        '/api/v2/torrents/pause',
        data: FormData.fromMap({'hashes': hash}),
        options: _authOptions,
      );
      return response.statusCode == 200;
    } catch (e) {
      appLogger.e('qBit pause error', error: e);
      return false;
    }
  }

  /// Resume a torrent
  Future<bool> resumeTorrent(String hash) async {
    final loggedIn = await _ensureLoggedIn();
    if (!loggedIn) return false;
    
    try {
      final response = await _dio.post(
        '/api/v2/torrents/resume',
        data: FormData.fromMap({'hashes': hash}),
        options: _authOptions,
      );
      return response.statusCode == 200;
    } catch (e) {
      appLogger.e('qBit resume error', error: e);
      return false;
    }
  }

  /// Delete a torrent
  Future<bool> deleteTorrent(String hash, {bool deleteFiles = false}) async {
    final loggedIn = await _ensureLoggedIn();
    if (!loggedIn) return false;
    
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
      appLogger.e('qBit delete error', error: e);
      return false;
    }
  }

  /// Get transfer info (global speeds)
  Future<Map<String, dynamic>?> getTransferInfo() async {
    final loggedIn = await _ensureLoggedIn();
    if (!loggedIn) return null;
    
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
      appLogger.e('qBit transfer info error', error: e);
      return null;
    }
  }
}
