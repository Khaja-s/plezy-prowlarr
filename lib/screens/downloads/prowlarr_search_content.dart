import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/prowlarr_release.dart';
import '../../models/prowlarr_config.dart';
import '../../services/prowlarr_client.dart';
import '../../services/settings_service.dart';
import '../../widgets/app_icon.dart';
import '../../utils/snackbar_helper.dart';

/// Content widget for the Prowlarr tab in Downloads screen
class ProwlarrSearchContent extends StatefulWidget {
  final bool suppressAutoFocus;
  final VoidCallback? onBack;
  final VoidCallback? onNavigateLeft;

  const ProwlarrSearchContent({
    super.key,
    this.suppressAutoFocus = false,
    this.onBack,
    this.onNavigateLeft,
  });

  @override
  State<ProwlarrSearchContent> createState() => _ProwlarrSearchContentState();
}

class _ProwlarrSearchContentState extends State<ProwlarrSearchContent> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode(debugLabel: 'prowlarr_search');
  final _firstResultFocusNode = FocusNode(debugLabel: 'prowlarr_first_result');

  List<ProwlarrRelease> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _error;
  ProwlarrClient? _client;
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _initClient();
  }

  Future<void> _initClient() async {
    final settingsService = await SettingsService.getInstance();
    final config = settingsService.getProwlarrConfig();

    if (mounted) {
      setState(() {
        _isConfigured = config != null && config.isValid;
        if (_isConfigured) {
          _client = ProwlarrClient(config: config!);
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _firstResultFocusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      final results = await _client!.search(query: query, limit: 50);
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _grabRelease(ProwlarrRelease release) async {
    try {
      final success = await _client!.grabRelease(
        indexerId: release.indexerId,
        guid: release.guid,
      );

      if (mounted) {
        if (success) {
          showSuccessSnackBar(context, 'Sent "${release.title}" to download client');
        } else {
          showErrorSnackBar(context, 'Failed to send to download client');
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConfigured) {
      return _buildNotConfiguredState();
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildContent()),
      ],
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
              'Prowlarr Not Configured',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Go to Settings → Prowlarr to set up your server URL and API key.',
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search torrents...',
                prefixIcon: const Icon(Symbols.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Symbols.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _results = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _isSearching ? null : _performSearch,
            child: _isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(Symbols.error_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Search failed: $_error'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _performSearch,
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(Symbols.travel_explore_rounded, size: 64),
            const SizedBox(height: 16),
            Text(
              'Search for Movies & TV Shows',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Results will be searched across all your Prowlarr indexers',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(Symbols.search_off_rounded, size: 48),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return _buildResultsList();
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final release = _results[index];
        return _ReleaseCard(
          release: release,
          focusNode: index == 0 ? _firstResultFocusNode : null,
          onGrab: () => _grabRelease(release),
        );
      },
    );
  }
}

/// Card widget for displaying a single release
class _ReleaseCard extends StatelessWidget {
  final ProwlarrRelease release;
  final FocusNode? focusNode;
  final VoidCallback onGrab;

  const _ReleaseCard({
    required this.release,
    this.focusNode,
    required this.onGrab,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        focusNode: focusNode,
        borderRadius: BorderRadius.circular(12),
        onTap: onGrab,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                release.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _InfoChip(
                    icon: Symbols.dns_rounded,
                    label: release.indexer ?? 'Unknown',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Symbols.storage_rounded,
                    label: release.formattedSize,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Symbols.arrow_upward_rounded,
                    label: 'S:${release.seedersDisplay}',
                    color: _getSeedersColor(context, release.seeders),
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Symbols.arrow_downward_rounded,
                    label: 'L:${release.leechersDisplay}',
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: onGrab,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.download_rounded, size: 18),
                        SizedBox(width: 4),
                        Text('Grab'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSeedersColor(BuildContext context, int? seeders) {
    if (seeders == null) return Theme.of(context).colorScheme.onSurfaceVariant;
    if (seeders >= 50) return Colors.green;
    if (seeders >= 10) return Colors.orange;
    return Colors.red;
  }
}

/// Small chip for displaying release info
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: textColor),
        const SizedBox(width: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor),
        ),
      ],
    );
  }
}
