// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// Original overlapping membership peaks converging on one crisp decision.
/// Same geometry as web/favicon.svg; no third-party logo artwork.
class FuzzyMark extends StatelessWidget {
  const FuzzyMark({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Fuzzy Engine',
        image: true,
        child: SizedBox.square(
            dimension: size, child: CustomPaint(painter: _MarkPainter())),
      );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 48, 48), const Radius.circular(13)),
        Paint()..color = const Color(0xff13283a));
    final overlap = Path()
      ..moveTo(16, 35)
      ..lineTo(25.1, 19.3)
      ..lineTo(33, 35)
      ..close();
    canvas.drawPath(
        overlap, Paint()..color = const Color(0xff65d7d0).withAlpha(45));
    final left = Path()
      ..moveTo(7, 35)
      ..lineTo(20, 11)
      ..lineTo(33, 35);
    final right = Path()
      ..moveTo(15, 35)
      ..lineTo(30, 14)
      ..lineTo(41, 35);
    for (final item in [
      (left, const Color(0xff65d7d0)),
      (right, const Color(0xffffb860))
    ]) {
      canvas.drawPath(
          item.$1,
          Paint()
            ..color = item.$2
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeJoin = StrokeJoin.round);
    }
    canvas.drawLine(
        const Offset(8, 38),
        const Offset(40, 38),
        Paint()
          ..color = const Color(0xff94a8bc)
          ..strokeWidth = 1.5);
    canvas.drawCircle(
        const Offset(25, 27), 3, Paint()..color = const Color(0xfff1fbff));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
