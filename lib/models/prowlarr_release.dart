/// Category from Prowlarr indexer
class IndexerCategory {
  final int id;
  final String? name;
  final String? subCategoryList;

  const IndexerCategory({
    required this.id,
    this.name,
    this.subCategoryList,
  });

  factory IndexerCategory.fromJson(Map<String, dynamic> json) {
    return IndexerCategory(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String?,
      subCategoryList: json['subCategoryList'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subCategoryList': subCategoryList,
      };
}

/// A release/torrent result from Prowlarr search
class ProwlarrRelease {
  /// Unique identifier for the release
  final String guid;

  /// Release title (e.g., "Movie.Name.2024.1080p.BluRay.x264")
  final String title;

  /// The indexer ID this release came from
  final int indexerId;

  /// Name of the indexer (e.g., "1337x", "RARBG")
  final String? indexer;

  /// File size in bytes
  final int size;

  /// Number of seeders (null for usenet)
  final int? seeders;

  /// Number of leechers (null for usenet)
  final int? leechers;

  /// Direct magnet link (for torrents)
  final String? magnetUrl;

  /// Download URL (proxied through Prowlarr)
  final String? downloadUrl;

  /// Info/details page URL
  final String? infoUrl;

  /// Poster image URL if available
  final String? posterUrl;

  /// When the release was published
  final DateTime? publishDate;

  /// IMDB ID if matched
  final int? imdbId;

  /// TMDB ID if matched
  final int? tmdbId;

  /// TVDB ID if matched
  final int? tvdbId;

  /// Categories this release belongs to
  final List<IndexerCategory>? categories;

  /// Protocol: "torrent" or "usenet"
  final String? protocol;

  /// Age in days
  final int? age;

  const ProwlarrRelease({
    required this.guid,
    required this.title,
    required this.indexerId,
    this.indexer,
    required this.size,
    this.seeders,
    this.leechers,
    this.magnetUrl,
    this.downloadUrl,
    this.infoUrl,
    this.posterUrl,
    this.publishDate,
    this.imdbId,
    this.tmdbId,
    this.tvdbId,
    this.categories,
    this.protocol,
    this.age,
  });

  factory ProwlarrRelease.fromJson(Map<String, dynamic> json) {
    return ProwlarrRelease(
      guid: json['guid'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown',
      indexerId: json['indexerId'] as int? ?? 0,
      indexer: json['indexer'] as String?,
      size: json['size'] as int? ?? 0,
      seeders: json['seeders'] as int?,
      leechers: json['leechers'] as int?,
      magnetUrl: json['magnetUrl'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      infoUrl: json['infoUrl'] as String?,
      posterUrl: json['posterUrl'] as String?,
      publishDate: json['publishDate'] != null
          ? DateTime.tryParse(json['publishDate'] as String)
          : null,
      imdbId: json['imdbId'] as int?,
      tmdbId: json['tmdbId'] as int?,
      tvdbId: json['tvdbId'] as int?,
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => IndexerCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      protocol: json['protocol'] as String?,
      age: json['age'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'guid': guid,
        'title': title,
        'indexerId': indexerId,
        'indexer': indexer,
        'size': size,
        'seeders': seeders,
        'leechers': leechers,
        'magnetUrl': magnetUrl,
        'downloadUrl': downloadUrl,
        'infoUrl': infoUrl,
        'posterUrl': posterUrl,
        'publishDate': publishDate?.toIso8601String(),
        'imdbId': imdbId,
        'tmdbId': tmdbId,
        'tvdbId': tvdbId,
        'categories': categories?.map((e) => e.toJson()).toList(),
        'protocol': protocol,
        'age': age,
      };

  /// Human-readable file size
  String get formattedSize {
    if (size == 0) return 'Unknown';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var bytes = size.toDouble();
    var unitIndex = 0;
    while (bytes >= 1024 && unitIndex < units.length - 1) {
      bytes /= 1024;
      unitIndex++;
    }
    return '${bytes.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  /// Seeders display string
  String get seedersDisplay => seeders?.toString() ?? '?';

  /// Leechers display string
  String get leechersDisplay => leechers?.toString() ?? '?';

  /// Check if this is a torrent release
  bool get isTorrent =>
      protocol?.toLowerCase() == 'torrent' || magnetUrl != null;
}
