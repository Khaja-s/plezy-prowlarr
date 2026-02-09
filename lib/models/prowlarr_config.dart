/// Configuration for connecting to a Prowlarr instance
class ProwlarrConfig {
  /// The base URL of the Prowlarr server (e.g., http://192.168.1.100:9696)
  final String serverUrl;

  /// The API key for authentication
  final String apiKey;

  /// Whether Prowlarr integration is enabled
  final bool isEnabled;

  const ProwlarrConfig({
    required this.serverUrl,
    required this.apiKey,
    this.isEnabled = true,
  });

  factory ProwlarrConfig.fromJson(Map<String, dynamic> json) {
    return ProwlarrConfig(
      serverUrl: json['serverUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'serverUrl': serverUrl,
        'apiKey': apiKey,
        'isEnabled': isEnabled,
      };

  /// Create a copy with modified fields
  ProwlarrConfig copyWith({
    String? serverUrl,
    String? apiKey,
    bool? isEnabled,
  }) {
    return ProwlarrConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      apiKey: apiKey ?? this.apiKey,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// Check if the config has valid connection info
  bool get isValid => serverUrl.isNotEmpty && apiKey.isNotEmpty;
}
