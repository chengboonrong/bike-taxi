// The Midnight Transit Diagram design system: tokens, theme and world widgets.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import 'common.dart' show accepted, completed, requested, started;

abstract final class Swatch {
  static const midnight = Color(0xFF0B1230);
  static const panelLow = Color(0xFF0E1636);
  static const panel = Color(0xFF111A3D);
  static const panelHigh = Color(0xFF16204A);
  static const panelHighest = Color(0xFF1C2756);
  static const porcelain = Color(0xFFFFFFFF);
  static const mist = Color(0xFFB8C0DA);
  static const outline = Color(0xFF5A6390);
  static const hairline = Color(0xFF263059);
  static const dim = Color(0xFF3A4470);
  static const scarlet = Color(0xFFE21D2D);
  static const scarletText = Color(0xFFFF6B6B);
  static const cobalt = Color(0xFF1E5BFF);
  static const amber = Color(0xFFFFC20E);
  static const green = Color(0xFF22B14C);
}

/// The line ink for a ride status; null is a ride still being booked.
Color lineFor(String? status) => switch (status) {
      null => Swatch.scarlet,
      requested => Swatch.amber,
      accepted => Swatch.cobalt,
      started => Swatch.green,
      completed => Swatch.porcelain,
      _ => Swatch.dim,
    };

/// Text colour on a line-ink fill.
Color onLine(Color c) =>
    c == Swatch.amber || c == Swatch.green || c == Swatch.porcelain
        ? Swatch.midnight
        : Swatch.porcelain;

const tabular = [FontFeature.tabularFigures()];
const _r6 = BorderRadius.all(Radius.circular(6));
const _shape6 = RoundedRectangleBorder(borderRadius: _r6);
const _cond = 'BarlowCondensed';

const _text = TextTheme(
  displayMedium: TextStyle(
      fontFamily: _cond, fontWeight: FontWeight.w700, fontSize: 44, height: 1.0, fontFeatures: tabular),
  headlineSmall: TextStyle(
      fontFamily: _cond, fontWeight: FontWeight.w600, fontSize: 28, height: 1.1, fontFeatures: tabular),
  titleLarge: TextStyle(
      fontFamily: _cond, fontWeight: FontWeight.w600, fontSize: 22, letterSpacing: 0.6),
  titleMedium: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w600, fontSize: 18),
  bodyLarge: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w400, fontSize: 17, height: 1.35),
  bodyMedium: TextStyle(fontFamily: 'Barlow', fontWeight: FontWeight.w400, fontSize: 15, height: 1.35),
  labelLarge: TextStyle(
      fontFamily: _cond, fontWeight: FontWeight.w600, fontSize: 17, letterSpacing: 1.4),
  labelMedium: TextStyle(
      fontFamily: _cond, fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 1.4),
  labelSmall: TextStyle(
      fontFamily: _cond, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1.6),
);

OutlineInputBorder _field(Color color, double width) => OutlineInputBorder(
    borderRadius: _r6, borderSide: BorderSide(color: color, width: width));

// Status bar and gesture bar stay transparent over the midnight ground, with light icons.
final transitOverlay = SystemUiOverlayStyle.light.copyWith(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarContrastEnforced: false,
);

WidgetStateProperty<T> _states<T>(T Function(Set<WidgetState> s) resolve) =>
    WidgetStateProperty.resolveWith(resolve);

final transitTheme = ThemeData(
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Swatch.scarlet,
    onPrimary: Swatch.porcelain,
    secondary: Swatch.cobalt,
    onSecondary: Swatch.porcelain,
    tertiary: Swatch.amber,
    onTertiary: Swatch.midnight,
    error: Swatch.scarletText,
    onError: Swatch.midnight,
    surface: Swatch.midnight,
    onSurface: Swatch.porcelain,
    onSurfaceVariant: Swatch.mist,
    surfaceContainerLowest: Swatch.midnight,
    surfaceContainerLow: Swatch.panelLow,
    surfaceContainer: Swatch.panel,
    surfaceContainerHigh: Swatch.panelHigh,
    surfaceContainerHighest: Swatch.panelHighest,
    outline: Swatch.outline,
    outlineVariant: Swatch.hairline,
    inverseSurface: Swatch.porcelain,
    onInverseSurface: Swatch.midnight,
    inversePrimary: Swatch.scarlet,
    surfaceTint: Colors.transparent,
    shadow: Colors.transparent,
  ),
  scaffoldBackgroundColor: Swatch.midnight,
  fontFamily: 'Barlow',
  textTheme: _text,
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: Swatch.scarlet,
      foregroundColor: Swatch.porcelain,
      disabledBackgroundColor: Swatch.panelHighest,
      disabledForegroundColor: Swatch.mist.withValues(alpha: 0.6),
      minimumSize: const Size(64, 56),
      shape: _shape6,
      textStyle: _text.labelLarge,
    ).copyWith(
      // Keyboard focus (admin on the web) shows as a cobalt outline.
      side: _states((s) => s.contains(WidgetState.focused)
          ? const BorderSide(color: Swatch.cobalt, width: 2)
          : null),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Swatch.porcelain,
      minimumSize: const Size(64, 56),
      shape: _shape6,
      textStyle: _text.labelLarge,
    ).copyWith(
      side: _states((s) => s.contains(WidgetState.focused)
          ? const BorderSide(color: Swatch.cobalt, width: 2)
          : BorderSide(
              color: s.contains(WidgetState.disabled) ? Swatch.dim : Swatch.porcelain,
              width: 1.5)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
        foregroundColor: Swatch.porcelain, textStyle: _text.labelLarge, shape: _shape6),
  ),
  inputDecorationTheme: InputDecorationThemeData(
    border: _field(Swatch.outline, 1.5),
    enabledBorder: _field(Swatch.outline, 1.5),
    disabledBorder: _field(Swatch.hairline, 1.5),
    focusedBorder: _field(Swatch.cobalt, 2),
    errorBorder: _field(Swatch.scarletText, 1.5),
    focusedErrorBorder: _field(Swatch.scarletText, 2),
    labelStyle: const TextStyle(color: Swatch.mist),
    floatingLabelStyle: const TextStyle(color: Swatch.porcelain),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Swatch.midnight,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    height: 72,
    indicatorColor: Colors.transparent,
    indicatorShape: const Border(bottom: BorderSide(color: Swatch.scarlet, width: 3)),
    iconTheme: _states((s) => IconThemeData(
        color: s.contains(WidgetState.selected) ? Swatch.porcelain : Swatch.mist)),
    labelTextStyle: _states((s) => _text.labelSmall!.copyWith(
        color: s.contains(WidgetState.selected) ? Swatch.porcelain : Swatch.mist)),
  ),
  navigationRailTheme: NavigationRailThemeData(
    backgroundColor: Swatch.midnight,
    indicatorColor: Colors.transparent,
    indicatorShape: const Border(bottom: BorderSide(color: Swatch.scarlet, width: 3)),
    useIndicator: true,
    labelType: NavigationRailLabelType.all,
    selectedIconTheme: const IconThemeData(color: Swatch.porcelain),
    unselectedIconTheme: const IconThemeData(color: Swatch.mist),
    selectedLabelTextStyle: _text.labelMedium!.copyWith(color: Swatch.porcelain),
    unselectedLabelTextStyle: _text.labelMedium!.copyWith(color: Swatch.mist),
  ),
  switchTheme: SwitchThemeData(
    trackColor: _states((s) => s.contains(WidgetState.selected) && !s.contains(WidgetState.disabled)
        ? Swatch.green
        : Swatch.panelHighest),
    thumbColor: _states((s) => s.contains(WidgetState.disabled)
        ? Swatch.mist.withValues(alpha: 0.5)
        : s.contains(WidgetState.selected)
            ? Swatch.porcelain
            : Swatch.mist),
    trackOutlineColor: _states((s) => s.contains(WidgetState.selected)
        ? Colors.transparent
        : Swatch.outline),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Swatch.porcelain,
    contentTextStyle: _text.bodyMedium!.copyWith(color: Swatch.midnight),
    actionTextColor: Swatch.cobalt,
    shape: _shape6,
  ),
  dividerTheme: const DividerThemeData(color: Swatch.hairline, thickness: 1, space: 1),
  appBarTheme: AppBarThemeData(
    backgroundColor: Swatch.midnight,
    foregroundColor: Swatch.porcelain,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: _text.titleLarge!.copyWith(color: Swatch.porcelain),
    systemOverlayStyle: transitOverlay,
  ),
  textSelectionTheme: TextSelectionThemeData(
    cursorColor: Swatch.cobalt,
    selectionColor: Swatch.cobalt.withValues(alpha: 0.4),
    selectionHandleColor: Swatch.cobalt,
  ),
  scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Swatch.mist.withValues(alpha: 0.4))),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Swatch.porcelain, linearTrackColor: Swatch.hairline),
  listTileTheme: const ListTileThemeData(
      textColor: Swatch.porcelain, iconColor: Swatch.mist, minVerticalPadding: 12),
);

/// The primary action: a scarlet button that ends in an arrow.
Widget primaryButton(String label, VoidCallback? onPressed) => FilledButton.icon(
      onPressed: onPressed,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward),
      label: Text(label),
    );

/// A 1dp hairline over the top edge of [child] (navigation bars).
Widget hairlineAbove(Widget child) => DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Swatch.hairline))),
      child: child,
    );

/// `BIKE TAXI` over the four line inks, with an optional role tag.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.role});

  final String? role;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            const Text('BIKE TAXI',
                style: TextStyle(
                    fontFamily: _cond,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    height: 1.0,
                    letterSpacing: 2,
                    color: Swatch.porcelain)),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 3,
              children: [
                for (final c in const [Swatch.scarlet, Swatch.cobalt, Swatch.amber, Swatch.green])
                  SizedBox(width: 14, height: 3, child: ColoredBox(color: c)),
              ],
            ),
          ],
        ),
        if (role != null) LineChip(role!, Swatch.porcelain),
      ],
    );
  }
}

/// A line tag, like the board's "RED LINE"; [cancelled] strikes it through on dim.
class LineChip extends StatelessWidget {
  const LineChip(this.text, this.color, {super.key, this.cancelled = false});

  final String text;
  final Color color;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final fill = cancelled ? Swatch.dim : color;
    return DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: onLine(fill),
                decoration: cancelled ? TextDecoration.lineThrough : null,
                decorationColor: Swatch.porcelain,
              ),
        ),
      ),
    );
  }
}

/// The only container: a 1dp hairline frame, no fill, no shadow.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = 16});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Swatch.hairline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}

/// A square map control (locate, sign out).
class MapButton extends StatelessWidget {
  const MapButton(this.icon, this.tooltip, this.onPressed, {super.key});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ground = Swatch.midnight.withValues(alpha: 0.88);
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(48),
        shape: _shape6,
        side: BorderSide(color: Swatch.porcelain.withValues(alpha: 0.7), width: 1.5),
        backgroundColor: ground,
        disabledBackgroundColor: ground,
        foregroundColor: Swatch.porcelain,
        disabledForegroundColor: Swatch.mist.withValues(alpha: 0.5),
      ),
    );
  }
}

class Station {
  const Station(this.title, {this.subtitle, this.trailing, this.onTap, this.selected = false});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
}

// The station mark's centre, level with the first line of the title.
const _markY = 30.0;

/// The signature: a ride drawn as a vertical transit line. Stations before
/// [current] are passed, [current] is the interchange, the rest are ahead.
class StationLine extends StatefulWidget {
  const StationLine({
    super.key,
    required this.stations,
    required this.current,
    required this.color,
    this.live = false,
    this.cancelled = false,
  });

  final List<Station> stations;
  final int current;
  final Color color;
  final bool live;
  final bool cancelled;

  @override
  State<StationLine> createState() => _StationLineState();
}

class _StationLineState extends State<StationLine> with SingleTickerProviderStateMixin {
  late final _halo =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  // Where the last advance started; equal to current when nothing is growing.
  late int _from = widget.current;

  bool get _still => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncHalo();
  }

  @override
  void didUpdateWidget(StationLine old) {
    super.didUpdateWidget(old);
    if (widget.current != old.current) {
      final grows = widget.current > old.current && !widget.cancelled && !_still;
      _from = grows ? old.current : widget.current;
    }
    _syncHalo();
  }

  void _syncHalo() {
    if (widget.live && !widget.cancelled && !_still) {
      if (!_halo.isAnimating) _halo.repeat();
    } else {
      _halo.reset();
    }
  }

  @override
  void dispose() {
    _halo.dispose();
    super.dispose();
  }

  // Half-segments are numbered down the line: row i's upper half is 2i-1, its lower half 2i.
  double _fill(int half, double t) {
    final lo = 2 * _from, hi = 2 * widget.current;
    if (half < lo) return 1;
    if (half >= hi) return 0;
    return (t * (hi - lo) - (half - lo)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final grows = _from != widget.current;
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.current),
      tween: Tween(begin: grows ? 0 : 1, end: 1),
      duration: grows ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeOutExpo,
      builder: (context, t, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.stations.length; i++) _row(context, i, t),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int i, double t) {
    final s = widget.stations[i];
    final n = widget.stations.length;
    final text = Theme.of(context).textTheme;
    final now = widget.current;
    // Station names are condensed tracked caps, like the board's.
    final title = TextStyle(
      fontFamily: _cond,
      fontWeight: FontWeight.w600,
      fontSize: 19,
      letterSpacing: 1.2,
      color: i == now
          ? Swatch.porcelain
          : i < now
              ? Swatch.porcelain.withValues(alpha: 0.8)
              : Swatch.mist,
      decoration: i == now && widget.cancelled ? TextDecoration.lineThrough : null,
      decorationColor: Swatch.porcelain,
    );
    Widget content = Row(
      spacing: 8,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: Text(s.title.toUpperCase(), style: title)),
              if (s.subtitle != null)
                Text(s.subtitle!, style: text.bodyMedium!.copyWith(color: Swatch.mist)),
            ],
          ),
        ),
        ?s.trailing,
      ],
    );
    if (s.onTap == null) {
      content = Padding(padding: const EdgeInsets.fromLTRB(8, 18, 0, 14), child: content);
    } else {
      // A tappable station reads as an input beside the line; the selected one is focused cobalt.
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          type: MaterialType.transparency,
          shape: RoundedRectangleBorder(
            borderRadius: _r6,
            side: s.selected
                ? const BorderSide(color: Swatch.cobalt, width: 2)
                : const BorderSide(color: Swatch.outline, width: 1.5),
          ),
          child: InkWell(
            onTap: s.onTap,
            borderRadius: _r6,
            child: Padding(padding: const EdgeInsets.fromLTRB(12, 14, 12, 10), child: content),
          ),
        ),
      );
    }
    return MergeSemantics(
      child: Semantics(
        label: 'Step ${i + 1} of $n, ${s.title}, '
            '${i < now ? 'done' : i == now ? 'current' : 'upcoming'}',
        selected: s.onTap == null ? null : s.selected,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 40,
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _Rail(
                      color: widget.color,
                      mark: i.compareTo(now),
                      upper: i == 0 ? null : _fill(2 * i - 1, t),
                      lower: i == n - 1 ? null : _fill(2 * i, t),
                      cancelled: widget.cancelled,
                      halo: i == now && _halo.isAnimating ? _halo : null,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rail extends CustomPainter {
  _Rail({
    required this.color,
    required this.mark,
    required this.upper,
    required this.lower,
    required this.cancelled,
    this.halo,
  }) : super(repaint: halo);

  final Color color;
  final int mark; // -1 passed, 0 current, 1 ahead
  final double? upper, lower; // coloured share of each half; null when there is no half
  final bool cancelled;
  final Animation<double>? halo;

  @override
  void paint(Canvas canvas, Size size) {
    const x = 20.0;
    // The dim track is butt-capped so it never paints over the row above; the ink keeps
    // round caps, which show only at the head of a growing segment.
    final track = Paint()
      ..strokeWidth = 6
      ..color = Swatch.dim;
    final ink = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = color;
    void half(double top, double bottom, double? fill) {
      if (fill == null) return;
      if (cancelled) {
        for (var y = top; y < bottom; y += 14) {
          canvas.drawLine(Offset(x, y), Offset(x, (y + 8).clamp(top, bottom)), track);
        }
        return;
      }
      canvas.drawLine(Offset(x, top), Offset(x, bottom), track);
      if (fill > 0) {
        canvas.drawLine(Offset(x, top), Offset(x, top + (bottom - top) * fill), ink);
      }
    }

    half(0, _markY, upper);
    half(_markY, size.height, lower);

    const c = Offset(x, _markY);
    final markInk = cancelled ? Swatch.dim : color;
    final ring = Paint()..style = PaintingStyle.stroke;
    if (mark < 0) {
      canvas.drawCircle(c, 7, Paint()..color = markInk);
    } else if (mark == 0) {
      if (halo != null) {
        final p = Curves.easeOutCubic.transform(halo!.value);
        final scale = 1 + 0.9 * p;
        canvas.drawCircle(
            c,
            10.5 * scale,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5 * scale
              ..color = color.withValues(alpha: 0.45 * (1 - p)));
      }
      canvas.drawCircle(c, 13, Paint()..color = cancelled ? Swatch.midnight : Swatch.porcelain);
      canvas.drawCircle(c, 10.5, ring
        ..strokeWidth = 5
        ..color = markInk);
    } else {
      canvas.drawCircle(c, 7, Paint()..color = Swatch.midnight);
      canvas.drawCircle(c, 5.5, ring
        ..strokeWidth = 3
        ..color = Swatch.dim);
    }
  }

  @override
  bool shouldRepaint(_Rail old) => true;
}
