import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Everything that can show on screen except the one allowed text: type,
/// position, size, colour of every box and every text. Equal strings mean
/// two phones look the same.
String look(WidgetTester t, Set<String> skip) {
  final b = StringBuffer();
  void visit(Element e) {
    final w = e.widget;
    if (w is RichText && skip.contains(w.text.toPlainText())) return;
    if (w is Text && skip.contains(w.data)) return;
    if (w is SizedBox && w.key == const ValueKey('face')) {
      b.writeln('face ${e.renderObject!.paintBounds}');
      return;
    }
    final r = e.renderObject;
    if (r is RenderBox && r.hasSize) {
      b.write('${w.runtimeType} ${r.localToGlobal(Offset.zero)} ${r.size}');
      if (w is DecoratedBox) b.write(' ${w.decoration}');
      if (w is RichText) {
        b.write(
          ' ${w.text.toPlainText()} ${w.text.style?.color}'
          ' ${w.text.style?.fontSize}',
        );
      }
      if (w is ColoredBox) b.write(' ${w.color}');
      if (w is PhysicalShape) b.write(' ${w.color}');
      if (w is Opacity) b.write(' ${w.opacity}');
      b.writeln();
    }
    e.visitChildren(visit);
  }

  visit(t.element(find.byType(MaterialApp)));
  return b.toString();
}
