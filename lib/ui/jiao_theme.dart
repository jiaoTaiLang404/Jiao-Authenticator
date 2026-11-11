import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const brandName = 'Jiao Authenticator';
const appVersion = '0.1.3';
const pageInset = 20.0;

ThemeData jiaoTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? const Color(0xfff7f7f7) : const Color(0xff111111);
  final surface = dark ? const Color(0xff191919) : Colors.white;
  final canvas = dark ? const Color(0xff0a0a0a) : const Color(0xfff5f5f7);
  final secondary = dark ? const Color(0xffb0b0b0) : const Color(0xff55555c);
  final border = dark ? const Color(0xff343434) : const Color(0xffd9d9dc);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xff666666),
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ).copyWith(
        primary: ink,
        onPrimary: canvas,
        secondary: ink,
        onSecondary: canvas,
        surface: surface,
        onSurface: ink,
        onSurfaceVariant: secondary,
        surfaceContainerHighest: dark
            ? const Color(0xff252525)
            : const Color(0xffeaeaec),
        surfaceContainerLow: surface,
        surfaceTint: Colors.transparent,
        outline: dark ? const Color(0xff888888) : const Color(0xff73737a),
        outlineVariant: border,
        error: ink,
        onError: canvas,
      );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    textTheme: base.textTheme
        .copyWith(
          headlineLarge: TextStyle(
            color: ink,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: -0.6,
          ),
          headlineSmall: TextStyle(
            color: ink,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          titleMedium: TextStyle(
            color: ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: TextStyle(color: ink, fontSize: 14, height: 1.4),
        )
        .apply(fontFamily: 'Roboto'),
    dividerTheme: DividerThemeData(color: border, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: canvas),
    ),
  );
}

Color muted(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.30);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Image.asset(
            'artwork/jiao-launcher.png',
            fit: BoxFit.cover,
            cacheWidth: 320,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

class JiaoBackdrop extends StatelessWidget {
  const JiaoBackdrop({super.key, this.showFooterRule = true});

  final bool showFooterRule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          gradient: RadialGradient(
            center: const Alignment(0.95, -0.84),
            radius: 1.15,
            colors: dark
                ? const [
                    Color(0xff272727),
                    Color(0xff101010),
                    Color(0xff0a0a0a),
                  ]
                : const [Colors.white, Color(0xffeeedef), Color(0xfff5f5f7)],
            stops: const [0, .48, 1],
          ),
        ),
        child: CustomPaint(painter: _LightTrace(dark, showFooterRule)),
      ),
    );
  }
}

class _LightTrace extends CustomPainter {
  const _LightTrace(this.dark, this.showFooterRule);
  final bool dark;
  final bool showFooterRule;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = dark ? const Color(0x14ffffff) : const Color(0x0d111111);
    for (var i = 0; i < 5; i++) {
      final dx = i * 12.0;
      canvas.drawPath(
        Path()
          ..moveTo(size.width * .46 + dx, 0)
          ..cubicTo(
            size.width * .52 + dx,
            84,
            size.width * .77 + dx,
            85,
            size.width + 14 + dx,
            184,
          ),
        p,
      );
    }
    if (showFooterRule) {
      p.color = dark ? const Color(0x09ffffff) : const Color(0x08111111);
      canvas.drawLine(
        Offset(0, size.height - 72),
        Offset(size.width, size.height - 72),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_LightTrace oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.showFooterRule != showFooterRule;
}

Future<ui.FragmentProgram?>? _glassProgram;
final _floatingGlassBlur = ui.ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4);

class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.reduced,
    this.radius = 32,
    this.floating = false,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final bool reduced;
  final double radius;
  final bool floating;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  ui.FragmentShader? _shader;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (!widget.floating && ui.ImageFilter.isShaderFilterSupported) {
      _loadShader();
    }
  }

  Future<void> _loadShader() async {
    final program = await (_glassProgram ??= _tryLoadGlass());
    if (!mounted || program == null) return;
    final shader = program.fragmentShader();
    setState(() => _shader = shader);
  }

  static Future<ui.FragmentProgram?> _tryLoadGlass() async {
    try {
      return await ui.FragmentProgram.fromAsset('shaders/glass.frag');
    } on Exception {
      return null;
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final reduce = widget.reduced || MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(widget.radius);
    final border = theme.colorScheme.outlineVariant;
    final start = reduce
        ? theme.colorScheme.surface
        : widget.floating
        ? (dark ? const Color(0x76383838) : const Color(0xa8ffffff))
        : dark
        ? const Color(0xd6353535)
        : const Color(0xf5ffffff);
    final end = reduce
        ? theme.colorScheme.surface
        : widget.floating
        ? (dark ? const Color(0x55171717) : const Color(0x75f1f1f3))
        : dark
        ? const Color(0xde171717)
        : const Color(0xdcececee);
    Widget content = CustomPaint(
      foregroundPainter: _Rim(
        radius,
        reduce
            ? border
            : dark
            ? const Color(0x88ffffff)
            : Colors.white,
        reduce
            ? border
            : dark
            ? const Color(0x30ffffff)
            : const Color(0x44727272),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [start, end],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: widget.onTap == null
              ? widget.child
              : InkWell(onTap: widget.onTap, child: widget.child),
        ),
      ),
    );
    if (!reduce && widget.floating) {
      final softened = BackdropFilter(
        filter: _floatingGlassBlur,
        child: content,
      );
      content = LayoutBuilder(
        builder: (context, bounds) {
          if (!bounds.isTight ||
              !bounds.biggest.isFinite ||
              bounds.biggest.isEmpty) {
            return softened;
          }
          // Magnify behind the capsule around its own center. Its label and
          // icon are painted afterward at their original size.
          return RawMagnifier(
            size: bounds.biggest,
            magnificationScale: 1.10,
            child: softened,
          );
        },
      );
    } else if (!reduce) {
      final shader = _shader;
      shader?.setFloat(2, 9);
      content = BackdropFilter(
        filter: shader == null
            ? ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7)
            : ui.ImageFilter.shader(shader),
        child: content,
      );
    }
    content = ClipRRect(borderRadius: radius, child: content);
    if (widget.onTap != null) {
      content = Semantics(
        button: true,
        label: widget.semanticLabel,
        child: Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed && !MediaQuery.disableAnimationsOf(context)
                ? .965
                : 1,
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutBack,
            child: content,
          ),
        ),
      );
    }
    return content;
  }
}

class _Rim extends CustomPainter {
  const _Rim(this.radius, this.highlight, this.edge);
  final BorderRadius radius;
  final Color highlight;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [highlight, edge, edge, highlight],
        stops: const [0, .48, .82, 1],
      ).createShader(rect);
    canvas.drawRRect(radius.toRRect(rect).deflate(.5), paint);
  }

  @override
  bool shouldRepaint(_Rim oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.highlight != highlight ||
      oldDelegate.edge != edge;
}

void showNotice(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
