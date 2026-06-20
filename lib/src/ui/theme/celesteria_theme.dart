import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CelesteriaThemeMode {
  light,
  dark,
  auto,
}

class CelesteriaThemeData {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color onBackground;
  final Color onSurface;
  final Color primary;
  final Color secondary;
  final Color accentPurple;
  final Color accentMagenta;
  final Color border;
  final double blurSigma;
  final List<Color> splatterColors;

  const CelesteriaThemeData({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.onBackground,
    required this.onSurface,
    required this.primary,
    required this.secondary,
    required this.accentPurple,
    required this.accentMagenta,
    required this.border,
    required this.blurSigma,
    required this.splatterColors,
  });

  static CelesteriaThemeData get dark => const CelesteriaThemeData(
        brightness: Brightness.dark,
        background: Color(0xFF0E0E10),
        surface: Color(0x99131315), // Semi-transparent glass
        onBackground: Color(0xFFE5E1E4),
        onSurface: Color(0xFFFDFFFE),
        primary: Color(0xFF00FBFB), // Neon Cyan
        secondary: Color(0xFF8B5CF6), // Neon Purple
        accentPurple: Color(0xFF571BC1),
        accentMagenta: Color(0xFFFF007F), // Neon Magenta for splashes
        border: Color(0x26FFFFFF), // White with 15% opacity
        blurSigma: 30.0,
        splatterColors: [
          Color(0x33FF007F), // Magenta splatter
          Color(0x26571BC1), // Deep purple splatter
          Color(0x2600FBFB), // Cyan splatter
        ],
      );

  static CelesteriaThemeData get light => const CelesteriaThemeData(
        brightness: Brightness.light,
        background: Color(0xFFF2F4F6),
        surface: Color(0xB3FFFFFF), // Translucent white glass
        onBackground: Color(0xFF191C1E),
        onSurface: Color(0xFF191C1E),
        primary: Color(0xFF005C55), // Teal
        secondary: Color(0xFF5516BE), // Deep violet
        accentPurple: Color(0xFF8B5CF6),
        accentMagenta: Color(0xFFFF1493),
        border: Color(0x26000000), // Black with 15% opacity
        blurSigma: 20.0,
        splatterColors: [
          Color(0x26FF1493), // Pink splatter
          Color(0x1F8B5CF6), // Pastel violet splatter
          Color(0x1F005C55), // Soft teal splatter
        ],
      );
}

class CelesteriaTheme extends InheritedWidget {
  final CelesteriaThemeData data;
  final CelesteriaThemeMode mode;
  final ValueChanged<CelesteriaThemeMode> onModeChanged;

  const CelesteriaTheme({
    super.key,
    required this.data,
    required this.mode,
    required this.onModeChanged,
    required super.child,
  });

  static CelesteriaThemeData of(BuildContext context) {
    final CelesteriaTheme? inherited =
        context.dependOnInheritedWidgetOfExactType<CelesteriaTheme>();
    if (inherited == null) {
      return CelesteriaThemeData.dark;
    }
    return inherited.data;
  }

  static CelesteriaTheme controllerOf(BuildContext context) {
    final CelesteriaTheme? inherited =
        context.dependOnInheritedWidgetOfExactType<CelesteriaTheme>();
    if (inherited == null) {
      throw StateError('No CelesteriaTheme found in context');
    }
    return inherited;
  }

  @override
  bool updateShouldNotify(CelesteriaTheme oldWidget) {
    return data != oldWidget.data || mode != oldWidget.mode;
  }
}

class CelesteriaThemeProvider extends StatefulWidget {
  final Widget child;
  final CelesteriaThemeMode initialMode;

  const CelesteriaThemeProvider({
    super.key,
    required this.child,
    this.initialMode = CelesteriaThemeMode.auto,
  });

  @override
  State<CelesteriaThemeProvider> createState() =>
      _CelesteriaThemeProviderState();
}

class _CelesteriaThemeProviderState extends State<CelesteriaThemeProvider>
    with WidgetsBindingObserver {
  late CelesteriaThemeMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode == CelesteriaThemeMode.auto) {
      setState(() {});
    }
  }

  void _changeMode(CelesteriaThemeMode newMode) {
    if (_mode != newMode) {
      setState(() {
        _mode = newMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness systemBrightness =
        MediaQuery.platformBrightnessOf(context);
    final CelesteriaThemeData currentData;

    switch (_mode) {
      case CelesteriaThemeMode.light:
        currentData = CelesteriaThemeData.light;
        break;
      case CelesteriaThemeMode.dark:
        currentData = CelesteriaThemeData.dark;
        break;
      case CelesteriaThemeMode.auto:
        currentData = systemBrightness == Brightness.dark
            ? CelesteriaThemeData.dark
            : CelesteriaThemeData.light;
        break;
    }

    return CelesteriaTheme(
      data: currentData,
      mode: _mode,
      onModeChanged: _changeMode,
      child: widget.child,
    );
  }
}

/// Custom painter that draws ACG paint splatters and ink drips on the canvas.
class PaintSplatterPainter extends CustomPainter {
  final List<Color> splatterColors;
  final int seed;

  PaintSplatterPainter({
    required this.splatterColors,
    this.seed = 42,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (splatterColors.isEmpty) return;

    final math.Random random = math.Random(seed);

    // Draw 3-5 splatters based on size
    final int splatterCount = 3 + random.nextInt(3);

    for (int i = 0; i < splatterCount; i++) {
      final double cx = random.nextDouble() * size.width;
      final double cy = random.nextDouble() * size.height;
      final double baseRadius = 25.0 + random.nextDouble() * 55.0;
      final Color color = splatterColors[random.nextInt(splatterColors.length)];

      final Paint paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);

      // Draw main blob
      canvas.drawCircle(Offset(cx, cy), baseRadius, paint);

      // Draw some irregular splatter droplets surrounding the main blob
      final int dropletCount = 6 + random.nextInt(8);
      for (int d = 0; d < dropletCount; d++) {
        final double angle = random.nextDouble() * 2 * math.pi;
        final double distance = baseRadius * (1.1 + random.nextDouble() * 0.9);
        final double dx = cx + math.cos(angle) * distance;
        final double dy = cy + math.sin(angle) * distance;
        final double dRadius = 3.0 + random.nextDouble() * (baseRadius * 0.15);

        // Splat trails
        if (random.nextBool()) {
          final Path trailPath = Path()
            ..moveTo(cx + math.cos(angle) * baseRadius * 0.8,
                cy + math.sin(angle) * baseRadius * 0.8)
            ..quadraticBezierTo(
              cx + math.cos(angle) * distance * 0.9,
              cy + math.sin(angle) * distance * 0.9,
              dx,
              dy,
            );
          final Paint trailPaint = Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = dRadius * 0.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
          canvas.drawPath(trailPath, trailPaint);
        }

        canvas.drawCircle(Offset(dx, dy), dRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PaintSplatterPainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.splatterColors != splatterColors;
  }
}
