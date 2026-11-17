// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:fuzzy_engine/fuzzy_engine.dart';

class MembershipPlot extends CustomPainter {
  MembershipPlot(this.variable, this.value);
  final FuzzyVariable variable;
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [Color(0xff54c8ff), Color(0xffffb860), Color(0xffff719d)];
    var index = 0;
    for (final f in variable.terms.values) {
      final path = Path();
      for (var i = 0; i <= 200; i++) {
        final x = variable.min + (variable.max - variable.min) * i / 200;
        final y = size.height * (1 - f.degree(x));
        if (i == 0) {
          path.moveTo(0, y);
        } else {
          path.lineTo(size.width * i / 200, y);
        }
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = colors[index++ % colors.length]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    final x =
        (value - variable.min) / (variable.max - variable.min) * size.width;
    canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = Colors.grey
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant MembershipPlot oldDelegate) =>
      oldDelegate.value != value || oldDelegate.variable != variable;
}
