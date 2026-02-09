/// Model for a qBittorrent torrent
class QBitTorrent {
  final String hash;
  final String name;
  final int size;
  final int progress; // 0-100
  final int dlSpeed; // bytes/s
  final int upSpeed; // bytes/s
  final int numSeeds;
  final int numLeechers;
  final int numConnectedSeeds;
  final int numConnectedLeechers;
  final String state;
  final int eta; // seconds, -1 if unknown
  final int downloaded;
  final int uploaded;
  final double ratio;

  const QBitTorrent({
    required this.hash,
    required this.name,
    required this.size,
    required this.progress,
    required this.dlSpeed,
    required this.upSpeed,
    required this.numSeeds,
    required this.numLeechers,
    required this.numConnectedSeeds,
    required this.numConnectedLeechers,
    required this.state,
    required this.eta,
    required this.downloaded,
    required this.uploaded,
    required this.ratio,
  });

  factory QBitTorrent.fromJson(Map<String, dynamic> json) {
    return QBitTorrent(
      hash: json['hash'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      size: json['size'] as int? ?? 0,
      progress: ((json['progress'] as num? ?? 0) * 100).round(),
      dlSpeed: json['dlspeed'] as int? ?? 0,
      upSpeed: json['upspeed'] as int? ?? 0,
      numSeeds: json['num_complete'] as int? ?? 0,
      numLeechers: json['num_incomplete'] as int? ?? 0,
      numConnectedSeeds: json['num_seeds'] as int? ?? 0,
      numConnectedLeechers: json['num_leechs'] as int? ?? 0,
      state: json['state'] as String? ?? 'unknown',
      eta: json['eta'] as int? ?? -1,
      downloaded: json['downloaded'] as int? ?? 0,
      uploaded: json['uploaded'] as int? ?? 0,
      ratio: (json['ratio'] as num? ?? 0).toDouble(),
    );
  }

  /// Human-readable file size
  String get formattedSize => _formatBytes(size);
  
  /// Human-readable download speed
  String get formattedDlSpeed => '${_formatBytes(dlSpeed)}/s';
  
  /// Human-readable upload speed
  String get formattedUpSpeed => '${_formatBytes(upSpeed)}/s';
  
  /// Human-readable ETA
  String get formattedEta {
    if (eta < 0 || eta == 8640000) return '∞';
    if (eta == 0) return 'Done';
    final hours = eta ~/ 3600;
    final minutes = (eta % 3600) ~/ 60;
    final seconds = eta % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  /// Is actively downloading
  bool get isDownloading => state == 'downloading' || state == 'stalledDL' || state == 'forcedDL';
  
  /// Is seeding
  bool get isSeeding => state == 'uploading' || state == 'stalledUP' || state == 'forcedUP';
  
  /// Is paused
  bool get isPaused => state == 'pausedDL' || state == 'pausedUP';
  
  /// Is complete
  bool get isComplete => progress >= 100;

  /// Display state
  String get displayState {
    switch (state) {
      case 'downloading': return 'Downloading';
      case 'stalledDL': return 'Stalled';
      case 'forcedDL': return 'Forced DL';
      case 'uploading': return 'Seeding';
      case 'stalledUP': return 'Seeding';
      case 'forcedUP': return 'Forced UP';
      case 'pausedDL': return 'Paused';
      case 'pausedUP': return 'Paused';
      case 'queuedDL': return 'Queued';
      case 'queuedUP': return 'Queued';
      case 'checkingDL': return 'Checking';
      case 'checkingUP': return 'Checking';
      case 'error': return 'Error';
      case 'missingFiles': return 'Missing';
      default: return state;
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var b = bytes.toDouble();
    var i = 0;
    while (b >= 1024 && i < units.length - 1) {
      b /= 1024;
      i++;
    }
    return '${b.toStringAsFixed(1)} ${units[i]}';
  }
}

/// qBittorrent configuration
class QBitConfig {
  final String serverUrl;
  final String? username;
  final String? password;

  const QBitConfig({
    required this.serverUrl,
    this.username,
    this.password,
  });

  bool get isValid => serverUrl.isNotEmpty;
}
