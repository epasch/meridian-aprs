import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/packet/station.dart';
import 'aprs_symbol_widget.dart';

/// A [SearchDelegate] that filters the known station map by callsign.
///
/// The station snapshot is taken at search-open time — no live updates are
/// applied while the search overlay is open. Tapping a result closes the
/// overlay and returns the selected [Station] to the caller.
class StationSearchDelegate extends SearchDelegate<Station?> {
  StationSearchDelegate({required this.stations});

  /// Snapshot of currently known stations, keyed by callsign.
  final Map<String, Station> stations;

  @override
  String get searchFieldLabel => 'Search callsign\u2026';

  @override
  List<Widget> buildActions(BuildContext context) {
    if (query.isEmpty) return [];
    return [
      IconButton(
        icon: const Icon(Symbols.close),
        tooltip: 'Clear',
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Symbols.arrow_back),
      tooltip: 'Back',
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final trimmed = query.trim().toUpperCase();
    final filtered =
        stations.values
            .where(
              (s) =>
                  trimmed.isEmpty || s.callsign.toUpperCase().contains(trimmed),
            )
            .toList()
          ..sort((a, b) => b.lastHeard.compareTo(a.lastHeard));

    if (filtered.isEmpty) {
      final theme = Theme.of(context);
      final message = trimmed.isEmpty
          ? 'No stations heard yet.'
          : 'No stations match \u201c$query\u201d.';
      return Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final s = filtered[index];
        return ListTile(
          leading: AprsSymbolWidget(
            symbolTable: s.symbolTable,
            symbolCode: s.symbolCode,
            size: 32,
          ),
          title: Text(s.callsign),
          subtitle: s.comment.isNotEmpty
              ? Text(s.comment, maxLines: 1, overflow: TextOverflow.ellipsis)
              : null,
          onTap: () => close(context, s),
        );
      },
    );
  }
}
