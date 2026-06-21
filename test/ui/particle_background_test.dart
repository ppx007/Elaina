import 'package:elaina/src/ui/widgets/particle_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('particle background repaints after color changes',
      (WidgetTester tester) async {
    Widget host(List<Color> colors) {
      return MaterialApp(
        home: SizedBox(
          width: 320,
          height: 240,
          child: ParticleBackground(
            particleCount: 8,
            colors: colors,
          ),
        ),
      );
    }

    await tester.pumpWidget(
      host(const <Color>[Color(0xFF00FBFB), Color(0xFFFF1493)]),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final Finder particleBackground = find.byType(ParticleBackground);
    expect(
      find.descendant(
        of: particleBackground,
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: particleBackground,
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      host(const <Color>[Color(0xFF005C55), Color(0xFF5516BE)]),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      find.descendant(
        of: particleBackground,
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });
}
