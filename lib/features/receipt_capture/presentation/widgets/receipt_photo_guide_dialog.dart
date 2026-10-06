import 'package:flutter/material.dart';

/// One-time educational dialog shown before the first receipt photo.
///
/// Explains how to capture correctly (light, framing, flat) so the AI
/// reads the receipt on the first try. Shown only once — persistence is
/// handled by `ReceiptPhotoGuidePrefs` in the camera screen.
class ReceiptPhotoGuideDialog extends StatelessWidget {
  const ReceiptPhotoGuideDialog({super.key, this.onConfirm});

  /// Called when the user taps "Entendido". Defaults to popping the dialog.
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('receipt-guide-dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.receipt_long_outlined, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cómo tomar una buena foto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sigue estos 3 tips para que la IA lea tu recibo a la primera:',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          SizedBox(height: 14),
          _GuideTip(
            icon: Icons.light_mode_outlined,
            title: '1. Busca buena luz',
            subtitle: 'Evita sombras y brillos sobre el papel.',
          ),
          SizedBox(height: 10),
          _GuideTip(
            icon: Icons.crop_free_outlined,
            title: '2. Encuadra completo',
            subtitle: 'Que se vean los bordes, el total y el comercio.',
          ),
          SizedBox(height: 10),
          _GuideTip(
            icon: Icons.straighten_outlined,
            title: '3. Ponlo recto',
            subtitle: 'Apóyalo en una superficie plana y oscura.',
          ),
        ],
      ),
      actions: [
        FilledButton(
          key: const Key('receipt-guide-confirm'),
          onPressed: () {
            final confirm = onConfirm;
            if (confirm != null) {
              confirm();
            } else {
              Navigator.of(context).pop();
            }
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Entendido, tomar foto',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              'Solo te mostramos esto una vez.',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    );
  }
}

class _GuideTip extends StatelessWidget {
  const _GuideTip({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F2D8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF546E00)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
