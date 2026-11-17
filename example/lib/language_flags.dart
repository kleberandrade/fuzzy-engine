// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'app_settings.dart';

/// Locally drawn national flag motifs, clipped to a circle. Original geometry;
/// no emoji, external artwork, font glyphs or runtime network assets.
class LanguageFlags extends StatelessWidget {
  const LanguageFlags({super.key, required this.settings});
  final AppSettings settings;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (final code in ['pt-BR', 'en'])
          Semantics(
            selected: settings.portuguese == (code == 'pt-BR'),
            child: IconButton(
              key: ValueKey('language-$code'),
              tooltip: code == 'pt-BR'
                  ? 'Português (Brasil)'
                  : 'English (United Kingdom)',
              onPressed: () => settings.setLanguage(code),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: const EdgeInsets.all(4),
              icon: Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          width: 2,
                          color: settings.portuguese == (code == 'pt-BR')
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent)),
                  child: ExcludeSemantics(
                      child:
                          CustomPaint(painter: _FlagPainter(code == 'pt-BR')))),
            ),
          ),
      ]);
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.brazil);
  final bool brazil;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    canvas.clipPath(Path()..addOval(const Rect.fromLTWH(0, 0, 40, 40)));
    if (brazil) {
      canvas.drawRect(const Rect.fromLTWH(0, 0, 40, 40),
          Paint()..color = const Color(0xff009739));
      canvas.drawPath(
          Path()
            ..moveTo(3, 20)
            ..lineTo(20, 7)
            ..lineTo(37, 20)
            ..lineTo(20, 33)
            ..close(),
          Paint()..color = const Color(0xffffdf00));
      canvas.drawCircle(
          const Offset(20, 20), 8.5, Paint()..color = const Color(0xff002776));
      canvas.save();
      canvas.clipPath(Path()
        ..addOval(Rect.fromCircle(center: const Offset(20, 20), radius: 8.5)));
      canvas.drawPath(
          Path()
            ..moveTo(10, 17)
            ..quadraticBezierTo(20, 14, 30, 23),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.restore();
      for (final p in [
        const Offset(17, 23),
        const Offset(23, 24),
        const Offset(20, 20)
      ]) canvas.drawCircle(p, .6, Paint()..color = Colors.white);
    } else {
      canvas.drawRect(const Rect.fromLTWH(0, 0, 40, 40),
          Paint()..color = const Color(0xff012169));
      for (final width in [10.0, 4.0]) {
        final paint = Paint()
          ..color = width == 10 ? Colors.white : const Color(0xffc8102e)
          ..strokeWidth = width;
        canvas.drawLine(const Offset(-4, -4), const Offset(44, 44), paint);
        canvas.drawLine(const Offset(-4, 44), const Offset(44, -4), paint);
      }
      for (final width in [13.0, 7.0]) {
        final paint = Paint()
          ..color = width == 13 ? Colors.white : const Color(0xffc8102e)
          ..strokeWidth = width;
        canvas.drawLine(const Offset(20, 0), const Offset(20, 40), paint);
        canvas.drawLine(const Offset(0, 20), const Offset(40, 20), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlagPainter oldDelegate) =>
      oldDelegate.brazil != brazil;
}
