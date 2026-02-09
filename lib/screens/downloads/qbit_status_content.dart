import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/qbit_torrent.dart';
import '../../services/qbit_client.dart';
import '../../services/settings_service.dart';
import '../../widgets/app_icon.dart';
import '../../utils/snackbar_helper.dart';

/// Content widget for the qBittorrent status tab
class QBitStatusContent extends StatefulWidget {
  final bool suppressAutoFocus;
  final VoidCallback? onBack;
  final VoidCallback? onNavigateLeft;

  const QBitStatusContent({
    super.key,
    this.suppressAutoFocus = false,
    this.onBack,
    this.onNavigateLeft,
  });

  @override
  State<QBitStatusContent> createState() => _QBitStatusContentState();
}

class _QBitStatusContentState extends State<QBitStatusContent> {
  List<QBitTorrent> _torrents = [];
  bool _isLoading = true;
  String? _error;
  QBitClient? _client;
  bool _isConfigured = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initClient();
  }

  Future<void> _initClient() async {
    final settingsService = await SettingsService.getInstance();
    final serverUrl = settingsService.getQbitServerUrl();

    if (mounted) {
      setState(() {
        _isConfigured = serverUrl.isNotEmpty;
        if (_isConfigured) {
          _client = QBitClient(
            config: QBitConfig(
              serverUrl: serverUrl,
              username: settingsService.getQbitUsername(),
              password: settingsService.getQbitPassword(),
            ),
          );
          _loadTorrents();
          // Auto-refresh every 3 seconds
          _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
            if (mounted) _loadTorrents();
          });
        } else {
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _loadTorrents() async {
    try {
      final torrents = await _client!.getTorrents();
      if (mounted) {
        setState(() {
          _torrents = torrents;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _togglePause(QBitTorrent torrent) async {
    try {
      bool success;
      if (torrent.isPaused) {
        success = await _client!.resumeTorrent(torrent.hash);
      } else {
        success = await _client!.pauseTorrent(torrent.hash);
      }
      if (success) {
        _loadTorrents();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to toggle torrent');
      }
    }
  }

  Future<void> _deleteTorrent(QBitTorrent torrent) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Torrent'),
        content: Text('Delete "${torrent.name}"?\n\nThis will not delete downloaded files.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _client!.deleteTorrent(torrent.hash);
        _loadTorrents();
        if (mounted) {
          showSuccessSnackBar(context, 'Torrent deleted');
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to delete torrent');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConfigured) {
      return _buildNotConfiguredState();
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_torrents.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadTorrents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _torrents.length,
        itemBuilder: (context, index) {
          return _TorrentCard(
            torrent: _torrents[index],
            onTogglePause: () => _togglePause(_torrents[index]),
            onDelete: () => _deleteTorrent(_torrents[index]),
          );
        },
      ),
    );
  }

  Widget _buildNotConfiguredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(Symbols.settings_suggest_rounded, size: 64),
            const SizedBox(height: 16),
            Text(
              'qBittorrent Not Configured',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Go to Settings → qBittorrent to set up your server URL.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(Symbols.error_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Connection Failed', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadTorrents,
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(Symbols.cloud_done_rounded, size: 64),
          const SizedBox(height: 16),
          Text(
            'No Active Downloads',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Your download queue is empty',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

/// Card widget for displaying a torrent
class _TorrentCard extends StatelessWidget {
  final QBitTorrent torrent;
  final VoidCallback onTogglePause;
  final VoidCallback onDelete;

  const _TorrentCard({
    required this.torrent,
    required this.onTogglePause,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    torrent.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Action buttons
                IconButton(
                  icon: Icon(
                    torrent.isPaused ? Symbols.play_arrow_rounded : Symbols.pause_rounded,
                    size: 20,
                  ),
                  onPressed: onTogglePause,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Symbols.delete_rounded, size: 20),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: torrent.progress / 100,
                minHeight: 6,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                color: _getProgressColor(context),
              ),
            ),
            const SizedBox(height: 10),
            // Stats row
            Row(
              children: [
                _buildChip(context, torrent.displayState, color: _getStateColor()),
                const SizedBox(width: 6),
                _buildChip(context, '${torrent.progress}%'),
                const SizedBox(width: 6),
                _buildChip(context, torrent.formattedSize),
                const Spacer(),
                // Speed indicators
                if (torrent.isDownloading) ...[
                  Icon(Symbols.arrow_downward_rounded, size: 14, color: Colors.green.shade600),
                  const SizedBox(width: 2),
                  Text(
                    torrent.formattedDlSpeed,
                    style: TextStyle(fontSize: 11, color: Colors.green.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
                if (torrent.isSeeding || torrent.upSpeed > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Symbols.arrow_upward_rounded, size: 14, color: Colors.blue.shade600),
                  const SizedBox(width: 2),
                  Text(
                    torrent.formattedUpSpeed,
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Peers row
            Row(
              children: [
                Icon(Symbols.group_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Seeds: ${torrent.numConnectedSeeds}/${torrent.numSeeds}  •  Peers: ${torrent.numConnectedLeechers}/${torrent.numLeechers}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const Spacer(),
                if (torrent.isDownloading && torrent.eta > 0) ...[
                  Icon(Symbols.schedule_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'ETA: ${torrent.formattedEta}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color != null ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Color _getProgressColor(BuildContext context) {
    if (torrent.isPaused) return Colors.grey;
    if (torrent.isComplete) return Colors.green;
    return Theme.of(context).colorScheme.primary;
  }

  Color _getStateColor() {
    if (torrent.isPaused) return Colors.grey;
    if (torrent.isSeeding) return Colors.blue.shade600;
    if (torrent.isDownloading) return Colors.green.shade600;
    return Colors.orange.shade600;
  }
}
