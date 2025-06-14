import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;

  const AppHeader({
    super.key,
    required this.title,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Row(
      children: [
        if (onBackPressed != null) ...[
          IconButton(
            onPressed: onBackPressed,
            icon: const Icon(Icons.arrow_back),
            style: IconButton.styleFrom(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            ),
          ),
          SizedBox(width: isSmallScreen ? 4 : 8),
        ],
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 24 : 28,
            ),
          ),
        ),
      ],
    );
  }
} 