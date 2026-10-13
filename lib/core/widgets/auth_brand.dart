import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Shared product mark and name for sign-in and account creation.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Image.asset(
          'assets/branding/finance-ai-app-icon.png',
          width: 96,
          height: 96,
          semanticLabel: 'Finance AI',
          fit: BoxFit.contain,
        ),
        if (showTitle) ...[
          Text(
            'Finance AI',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: palette.text,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'Tu dinero, más claro.',
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
          ),
        ],
      ],
    );
  }
}
