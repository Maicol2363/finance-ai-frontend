import 'package:finance_ai/core/icons/finance_icon_catalog.dart';
import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Mockup `.set-title`: uppercase section label above a group.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: palette.muted,
          ),
        ),
      ),
    );
  }
}

/// Mockup `.set-group`: rounded card that groups settings rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rows = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: palette.rowLine));
      }
      rows.add(children[index]);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

/// Mockup `.set-row`: label + value/subtitle, optionally tappable.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.subtitle,
    this.leading,
    this.value,
    this.onTap,
    this.rowKey,
  });

  final String label;
  final String? subtitle;
  final Widget? leading;
  final String? value;
  final VoidCallback? onTap;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: rowKey,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                )
              else if (subtitle != null)
                Flexible(
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: palette.muted),
                  ),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(FinanceIcons.chevronRight, size: 18, color: palette.nav),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mockup `.addrow`: dashed primary outline "+ Agregar ..." button.
class CatalogAddButton extends StatelessWidget {
  const CatalogAddButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.hint,
  });

  final String label;
  final String? hint;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null;
    final color = enabled ? palette.primary : palette.nav;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: DashedRoundedBorderPainter(color: color, radius: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FinanceIcons.add, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      hint!,
                      style: TextStyle(fontSize: 10.5, color: palette.muted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashedRoundedBorderPainter extends CustomPainter {
  const DashedRoundedBorderPainter({
    required this.color,
    required this.radius,
    this.dashLength = 6,
    this.gapLength = 4,
    this.strokeWidth = 1.5,
  });

  final Color color;
  final double radius;
  final double dashLength;
  final double gapLength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Performance optimization: Accumulate all extracted dash segments into
    // a single Path object and issue a single canvas.drawPath call, reducing
    // Canvas draw calls from O(N) to O(1) per widget repaint.
    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashLength).clamp(0.0, metric.length);
        dashPath.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + gapLength;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Mockup `.manage-card`: rounded card stacking catalog rows.
class ManageCard extends StatelessWidget {
  const ManageCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rows = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: palette.rowLine));
      }
      rows.add(children[index]);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

/// Shared surface for forms in account, budget, and catalog management.
class ManagementFormCard extends StatelessWidget {
  const ManagementFormCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.line),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Mockup `.manage-icon`: 34x34 rounded primary-soft icon box.
class ManageIcon extends StatelessWidget {
  const ManageIcon(this.icon, {super.key, this.background, this.foreground});

  final IconData icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background ?? palette.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 21, color: foreground ?? palette.primaryDark),
    );
  }
}

/// Mockup `.manage-row`: icon + swatch + title/subtitle + actions.
class ManageRow extends StatelessWidget {
  const ManageRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconBackground,
    this.iconForeground,
    this.swatchColor,
    this.trailing = const [],
    this.onTap,
    this.rowKey,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconBackground;
  final Color? iconForeground;
  final Color? swatchColor;
  final List<Widget> trailing;
  final VoidCallback? onTap;
  final Key? rowKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: rowKey,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              if (icon != null) ...[
                ManageIcon(
                  icon!,
                  background: iconBackground,
                  foreground: iconForeground,
                ),
                const SizedBox(width: 10),
              ],
              if (swatchColor != null)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: swatchColor,
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: palette.muted),
                        ),
                      ),
                  ],
                ),
              ),
              ...trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Mockup `.catalog-actions .iconbtn`: small rounded action button.
class ManageActionButton extends StatelessWidget {
  const ManageActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null;
    final iconColor = enabled
        ? (destructive ? palette.discard : palette.muted)
        : palette.muted.withValues(alpha: 0.38);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: Material(
          color: palette.soft,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(icon, size: 16, color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mockup `.seg`: small segmented control (Claro/Oscuro, COP/USD, ...).
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.keyPrefix,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget option(int index) => Semantics(
      button: true,
      selected: index == selectedIndex,
      label: labels[index],
      child: GestureDetector(
        key: keyPrefix == null ? null : Key('$keyPrefix-$index'),
        onTap: () => onChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: index == selectedIndex
                ? palette.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            labels[index],
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: index == selectedIndex ? palette.onPrimary : palette.muted,
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.soft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = constraints.hasBoundedWidth;
          return Row(
            mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              for (var index = 0; index < labels.length; index++)
                if (fillWidth)
                  Expanded(child: option(index))
                else
                  option(index),
            ],
          );
        },
      ),
    );
  }
}

/// One pill of a [FilterChipRow].
class FilterChipOption<T> {
  const FilterChipOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Mockup `.fchip`: horizontally scrollable pill filters.
///
/// Used by the history search screen for `Tipo` and `Periodo`. Pass a
/// [keyPrefix] to expose `Key('$keyPrefix-$index')` on each pill so widget
/// tests can tap a specific option.
class FilterChipRow<T> extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.keyPrefix,
  });

  final List<FilterChipOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            Builder(
              builder: (context) {
                final option = options[index];
                final isSelected = option.value == selected;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: option.label,
                  child: GestureDetector(
                    key: keyPrefix == null ? null : Key('$keyPrefix-$index'),
                    onTap: () => onChanged(option.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.primary : palette.card,
                        border: Border.all(
                          color: isSelected ? palette.primary : palette.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? palette.onPrimary : palette.muted,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Mockup `.f-label`: compact label above a form field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(
    this.label, {
    super.key,
    this.topSpacing = 14,
    this.uppercase = true,
  });

  final String label;
  final double topSpacing;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(top: topSpacing, left: 2, right: 2, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: palette.muted,
        ),
      ),
    );
  }
}

/// Mockup auth `.f-input`: pill-shaped input decoration.
InputDecoration pillInputDecoration(
  BuildContext context, {
  required String hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? errorText,
}) {
  final palette = context.palette;
  OutlineInputBorder border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    errorText: errorText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    border: border(palette.line, 1),
    enabledBorder: border(palette.line, 1),
    focusedBorder: border(palette.primary, 1.6),
    errorBorder: border(palette.discard, 1),
    focusedErrorBorder: border(palette.discard, 1.6),
  );
}
