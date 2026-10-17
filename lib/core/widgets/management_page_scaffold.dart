import 'package:flutter/material.dart';

import 'app_header.dart';

/// Shared page frame for account, budget, category, and income management.
///
/// The feature widget passed as [body] owns its scrolling, controller state,
/// and callbacks. This widget standardizes the header and content width only.
class ManagementPageScaffold extends StatelessWidget {
  const ManagementPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.maxWidth = 760,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 8, 16, 40),
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? leading;
  final List<Widget> actions;
  final double maxWidth;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: title,
              subtitle: subtitle,
              leading: leading,
              actions: actions,
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(padding: contentPadding, child: body),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
