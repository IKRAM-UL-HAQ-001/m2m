import 'package:flutter/material.dart';

class CallsPlaceholderTab extends StatelessWidget {
  const CallsPlaceholderTab({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isNotEmpty) {
      return SafeArea(
        top: false,
        bottom: true,
        child: ColoredBox(
          color: Colors.white,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No calls found',
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      bottom: true,
      child: ColoredBox(
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.call_outlined, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 20),
              Text(
                'No recent calls',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your call history will appear here',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
