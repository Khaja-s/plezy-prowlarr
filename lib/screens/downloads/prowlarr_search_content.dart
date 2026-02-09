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
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    _dismissKeyboard();

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
          showSuccessSnackBar(context, 'Sent to download client');
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

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildContent()),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search torrents...',
                  prefixIcon: const Icon(Symbols.search_rounded, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _performSearch(),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _isSearching ? null : _performSearch,
              child: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Search'),
            ),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(Symbols.error_rounded, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Search failed', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _performSearch,
                icon: const Icon(Symbols.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
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
              'Results from all Prowlarr indexers',
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final release = _results[index];
        return _ReleaseCard(
          release: release,
          onGrab: () => _grabRelease(release),
        );
      },
    );
  }
}

/// Card widget for displaying a single release - optimized for mobile
class _ReleaseCard extends StatelessWidget {
  final ProwlarrRelease release;
  final VoidCallback onGrab;

  const _ReleaseCard({
    required this.release,
    required this.onGrab,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onGrab,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                release.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // Info row with Grab button
              Row(
                children: [
                  // Indexer
                  _buildChip(
                    context,
                    release.indexer ?? 'Unknown',
                    color: Theme.of(context).colorScheme.primaryContainer,
                    textColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  // Size
                  _buildChip(context, release.formattedSize),
                  const SizedBox(width: 6),
                  // Seeders
                  _buildChip(
                    context,
                    '↑${release.seedersDisplay}',
                    color: _getSeedersColor(release.seeders),
                    textColor: Colors.white,
                  ),
                  const Spacer(),
                  // Grab button
                  SizedBox(
                    height: 32,
                    child: FilledButton.icon(
                      onPressed: onGrab,
                      icon: const Icon(Symbols.download_rounded, size: 16),
                      label: const Text('Grab'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
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

  Widget _buildChip(BuildContext context, String label, {Color? color, Color? textColor}) {
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
          color: textColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Color _getSeedersColor(int? seeders) {
    if (seeders == null) return Colors.grey;
    if (seeders >= 50) return Colors.green.shade600;
    if (seeders >= 10) return Colors.orange.shade600;
    return Colors.red.shade600;
  }
}
