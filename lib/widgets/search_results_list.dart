import 'package:flutter/material.dart';

import '../utils/constants.dart';

class SearchResultsList<T> extends StatelessWidget {
  const SearchResultsList({
    super.key,
    required this.query,
    required this.allItems,
    required this.getSearchableText,
    required this.buildTile,
    this.emptyTitle = 'No matches found',
  });

  final String query;
  final List<T> allItems;
  final String Function(T) getSearchableText;
  final Widget Function(T, bool isExact) buildTile;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();

    final q = query.toLowerCase();
    final exactMatches = allItems.where((item) {
      return getSearchableText(item).toLowerCase().startsWith(q);
    }).toList();
    final partialMatches = allItems.where((item) {
      final name = getSearchableText(item).toLowerCase();
      return name.contains(q) && !name.startsWith(q);
    }).toList();

    if (exactMatches.isEmpty && partialMatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '"$query" not found',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (exactMatches.isNotEmpty) ...[
          _sectionHeader('MATCHES', AppColors.primaryColor),
          ...exactMatches.map((item) => buildTile(item, true)),
        ],
        if (partialMatches.isNotEmpty) ...[
          _sectionHeader('SIMILAR MATCHES', Colors.grey[500]!),
          ...partialMatches.map((item) => buildTile(item, false)),
        ],
      ],
    );
  }

  Widget _sectionHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
