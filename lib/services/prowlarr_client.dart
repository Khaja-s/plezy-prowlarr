import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/prowlarr_config.dart';
import '../models/prowlarr_release.dart';
import '../utils/app_logger.dart';

/// Client for communicating with Prowlarr API
class ProwlarrClient {
  final Dio _dio;
  final ProwlarrConfig config;

  ProwlarrClient({required this.config})
      : _dio = Dio(BaseOptions(
          baseUrl: config.serverUrl.endsWith('/')
              ? config.serverUrl.substring(0, config.serverUrl.length - 1)
              : config.serverUrl,
          headers: {
            'X-Api-Key': config.apiKey,
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60),
        ));

  /// Test connection to Prowlarr server
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/api/v1/system/status');
      return response.statusCode == 200;
    } catch (e) {
      appLogger.e('Prowlarr connection test failed', error: e);
      return false;
    }
  }

  /// Get Prowlarr version info
  Future<Map<String, dynamic>?> getSystemStatus() async {
    try {
      final response = await _dio.get('/api/v1/system/status');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      appLogger.e('Failed to get Prowlarr status', error: e);
      return null;
    }
  }

  /// Search for releases across all indexers
  /// 
  /// [query] - The search term
  /// [categories] - Optional category IDs (2000=Movies, 5000=TV, 3000=Audio)
  /// [limit] - Max results to fetch (default 100)
  /// [sortBy] - Sort results by 'seeders', 'size', or 'date' (client-side)
  Future<List<ProwlarrRelease>> search({
    required String query,
    List<int>? categories,
    int limit = 100,
    String sortBy = 'seeders',
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'query': query,
        'limit': limit,
        'type': 'search',
      };

      if (categories != null && categories.isNotEmpty) {
        queryParams['categories'] = categories.join(',');
      }

      final response = await _dio.get(
        '/api/v1/search',
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data as List<dynamic>;
      final releases = data
          .map((json) => ProwlarrRelease.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort client-side (Prowlarr API doesn't support server-side sorting)
      switch (sortBy) {
        case 'seeders':
          releases.sort((a, b) => (b.seeders ?? 0).compareTo(a.seeders ?? 0));
          break;
        case 'size':
          releases.sort((a, b) => b.size.compareTo(a.size));
          break;
        case 'date':
          releases.sort((a, b) => (b.publishDate ?? DateTime(1970))
              .compareTo(a.publishDate ?? DateTime(1970)));
          break;
      }

      return releases;
    } catch (e) {
      appLogger.e('Prowlarr search failed', error: e);
      rethrow;
    }
  }

  /// Grab a release and send it to the download client
  /// 
  /// [indexerId] - The indexer ID from the release
  /// [guid] - The release GUID
  /// [downloadClientId] - Optional specific download client ID
  Future<bool> grabRelease({
    required int indexerId,
    required String guid,
    int? downloadClientId,
  }) async {
    try {
      final payload = <String, dynamic>{
        'indexerId': indexerId,
        'guid': guid,
      };

      if (downloadClientId != null) {
        payload['downloadClientId'] = downloadClientId;
      }

      final response = await _dio.post(
        '/api/v1/search',
        data: jsonEncode(payload),
      );

      return response.statusCode == 200;
    } catch (e) {
      appLogger.e('Prowlarr grab failed', error: e);
      rethrow;
    }
  }

  /// Get list of configured indexers
  Future<List<Map<String, dynamic>>> getIndexers() async {
    try {
      final response = await _dio.get('/api/v1/indexer');
      return (response.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      appLogger.e('Failed to get indexers', error: e);
      return [];
    }
  }

  /// Get list of configured download clients
  Future<List<Map<String, dynamic>>> getDownloadClients() async {
    try {
      final response = await _dio.get('/api/v1/downloadclient');
      return (response.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      appLogger.e('Failed to get download clients', error: e);
      return [];
    }
  }
}
