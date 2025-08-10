// This file is extracted from the app's timeline implementation and minimally
// refactored to compile inside a package. Public API remains similar.

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef TimelineEventTap = void Function(TimelineEvent event);

enum TimeScaleLOD { hour, day, week, month, year, decade, century, millennium }

class TimelineEvent {
  final DateTime date;
  final String title;
  final String? description;
  const TimelineEvent({
    required this.date,
    required this.title,
    this.description,
  });
}

class TimelineWidget extends StatefulWidget {
  final double height;
  final List<TimelineEvent> events;
  final double minZoom;
  final double maxZoom;
  final double initialZoom;
  final double basePixelsPerMillisecond;
  final TimeScaleLOD? minLOD;
  final TimeScaleLOD? maxLOD;
  final TimeScaleLOD? minZoomLOD;
  final TimeScaleLOD? maxZoomLOD;
  final Color backgroundColor;
  final Color timelineColor;
  final Color eventColor;
  final Color tickLabelColor;
  // Thickness controls
  final double axisThickness;
  final double majorTickThickness;
  final double minorTickThickness;
  // Minor tick color override
  final Color? minorTickColor;
  // Optional per-LOD label styles
  final Map<TimeScaleLOD, TextStyle>? labelStyleByLOD;
  // Render every Nth major label (1 = all)
  final int labelStride;
  final Function(double)? onZoomChanged;
  final TimelineEventTap? onEventTap;
  final bool debugMode;

  const TimelineWidget({
    super.key,
    this.height = 120.0,
    this.events = const [],
    this.minZoom = 0.5,
    this.maxZoom = 3.0,
    this.initialZoom = 1.0,
    this.basePixelsPerMillisecond = 0.00002,
    this.minLOD,
    this.maxLOD,
    this.minZoomLOD,
    this.maxZoomLOD,
    this.backgroundColor = Colors.white,
    this.timelineColor = Colors.blue,
    this.eventColor = Colors.red,
    this.tickLabelColor = const Color(0xFF666666),
    this.axisThickness = 2.0,
    this.majorTickThickness = 2.0,
    this.minorTickThickness = 1.0,
    this.minorTickColor,
    this.labelStyleByLOD,
    this.labelStride = 1,
    this.onZoomChanged,
    this.onEventTap,
    this.debugMode = false,
  });

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  late double _zoom;
  double _panOffset = 0;
  double _lastViewWidth = 0;
  double _effectiveMinZoom = 0.5, _effectiveMaxZoom = 3.0;
  double? _initialCenterMs;

  @override
  void initState() {
    super.initState();
    _zoom = widget.initialZoom;
    _applyZoomLODExtents();
  }

  void _applyZoomLODExtents() {
    double minZ = widget.minZoom, maxZ = widget.maxZoom;
    if (widget.minZoomLOD != null || widget.maxZoomLOD != null) {
      const targetPx = 90.0;
      double majorMs(TimeScaleLOD lod) {
        switch (lod) {
          case TimeScaleLOD.hour:
            return 3600e3;
          case TimeScaleLOD.day:
            return 24 * 3600e3;
          case TimeScaleLOD.week:
            return 7 * 24 * 3600e3;
          case TimeScaleLOD.month:
            return 30 * 24 * 3600e3;
          case TimeScaleLOD.year:
            return 365 * 24 * 3600e3;
          case TimeScaleLOD.decade:
            return 10 * 365 * 24 * 3600e3;
          case TimeScaleLOD.century:
            return 100 * 365 * 24 * 3600e3;
          case TimeScaleLOD.millennium:
            return 1000 * 365 * 24 * 3600e3;
        }
      }

      double zoomFor(TimeScaleLOD lod) =>
          (targetPx / majorMs(lod)) / widget.basePixelsPerMillisecond;
      if (widget.minZoomLOD != null) minZ = zoomFor(widget.minZoomLOD!);
      if (widget.maxZoomLOD != null) maxZ = zoomFor(widget.maxZoomLOD!);
      if (minZ > maxZ) {
        final t = minZ;
        minZ = maxZ;
        maxZ = t;
      }
    }
    _effectiveMinZoom = minZ;
    _effectiveMaxZoom = maxZ;
    _zoom = _zoom.clamp(minZ, maxZ);
  }

  // Keep anchor under cursor/fingers during zoom
  void _zoomAnchored(double factor, double anchorX) {
    if (factor == 1 || !factor.isFinite) return;
    final newZoom = (_zoom * factor).clamp(
      _effectiveMinZoom,
      _effectiveMaxZoom,
    );
    final base = widget.basePixelsPerMillisecond;
    final oldScale = base * _zoom;
    final newScale = base * newZoom;
    final leftMsOld = -_panOffset / oldScale;
    final anchorMs = leftMsOld + anchorX / oldScale;
    final newLeftMs = anchorMs - anchorX / newScale;
    setState(() {
      _zoom = newZoom;
      _panOffset = -newLeftMs * newScale;
      widget.onZoomChanged?.call(_zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(
        context,
      ).copyWith(physics: const NeverScrollableScrollPhysics()),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) => true,
        child: LayoutBuilder(
          builder: (ctx, cts) {
            _lastViewWidth = cts.maxWidth;
            return Listener(
              onPointerSignal: (e) {
                if (e is PointerScrollEvent) {
                  // Handle both vertical and horizontal scroll inputs
                  final dy = e.scrollDelta.dy;
                  final dx = e.scrollDelta.dx;
                  double factor = 1.0;
                  if (dy != 0) {
                    factor = math.pow(1.0015, -dy).toDouble();
                  } else if (dx != 0) {
                    factor = math.pow(1.0015, dx).toDouble();
                  }
                  if (factor != 1.0 && factor.isFinite) {
                    _zoomAnchored(factor, e.localPosition.dx);
                  }
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _centerOnMidpoint,
                onTapDown: (d) {
                  if (widget.onEventTap == null) return;
                  final hit = _hitTestEvent(
                    d.localPosition,
                    Size(cts.maxWidth, widget.height),
                  );
                  if (hit != null) widget.onEventTap!(hit);
                },
                onScaleUpdate: (details) {
                  final box = context.findRenderObject() as RenderBox;
                  final local = box.globalToLocal(details.focalPoint);
                  if (details.scale != 1.0) {
                    // Pinch zoom anchored at focal point
                    _zoomAnchored(details.scale, local.dx);
                  } else {
                    // Trackpad vertical pan interpreted as zoom gesture
                    final dx = details.focalPointDelta.dx.abs();
                    final dy = details.focalPointDelta.dy.abs();
                    if (dy > dx && details.focalPointDelta.dy != 0) {
                      final factor = math
                          .pow(1.0015, -details.focalPointDelta.dy)
                          .toDouble();
                      _zoomAnchored(factor, local.dx);
                    } else {
                      _panOffset += details.focalPointDelta.dx;
                      setState(() {});
                    }
                  }
                },
                child: CustomPaint(
                  size: Size(cts.maxWidth, widget.height),
                  painter: _Painter(
                    events: widget.events,
                    zoom: _zoom,
                    panOffset: _panOffset,
                    timelineColor: widget.timelineColor,
                    eventColor: widget.eventColor,
                    basePxPerMs: widget.basePixelsPerMillisecond,
                    tickLabelColor: widget.tickLabelColor,
                    axisThickness: widget.axisThickness,
                    majorTickThickness: widget.majorTickThickness,
                    minorTickThickness: widget.minorTickThickness,
                    minorTickColor: widget.minorTickColor,
                    labelStyleByLOD: widget.labelStyleByLOD,
                    labelStride: widget.labelStride,
                    debug: widget.debugMode,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _centerOnMidpoint() {
    if (_lastViewWidth <= 0) return;
    double? targetCenterMs;
    if (widget.events.isNotEmpty) {
      DateTime minDate = widget.events.first.date.toUtc();
      DateTime maxDate = minDate;
      for (final e in widget.events) {
        final d = e.date.toUtc();
        if (d.isBefore(minDate)) minDate = d;
        if (d.isAfter(maxDate)) maxDate = d;
      }
      targetCenterMs =
          (minDate.millisecondsSinceEpoch + maxDate.millisecondsSinceEpoch) /
          2.0;
    } else if (_initialCenterMs != null) {
      targetCenterMs = _initialCenterMs;
    }
    if (targetCenterMs == null) return;

    final base = widget.basePixelsPerMillisecond;
    final scale = base * _zoom;
    final leftMs = targetCenterMs - (_lastViewWidth / 2) / scale;
    setState(() {
      _panOffset = -leftMs * scale;
    });
  }

  TimelineEvent? _hitTestEvent(Offset p, Size size) {
    final base = widget.basePixelsPerMillisecond;
    final scale = base * _zoom;
    final leftMs = -_panOffset / scale;
    // naive marker hit test: circle radius 8 at axisY
    final axisY = size.height * 0.5;
    for (final ev in widget.events) {
      final x = (ev.date.millisecondsSinceEpoch.toDouble() - leftMs) * scale;
      if ((p - Offset(x, axisY)).distance <= 10) return ev;
    }
    return null;
  }
}

/// Paints the axis, delegates tick generation/labeling to `_PackageTickManager`,
/// and then draws event markers. Labels are only created for major ticks.
class _Painter extends CustomPainter {
  final List<TimelineEvent> events;
  final double zoom;
  final double panOffset;
  final Color timelineColor;
  final Color eventColor;
  final double basePxPerMs;
  final Color tickLabelColor;
  final double axisThickness;
  final double majorTickThickness;
  final double minorTickThickness;
  final Color? minorTickColor;
  final Map<TimeScaleLOD, TextStyle>? labelStyleByLOD;
  final int labelStride;
  final bool debug;
  _Painter({
    required this.events,
    required this.zoom,
    required this.panOffset,
    required this.timelineColor,
    required this.eventColor,
    required this.basePxPerMs,
    required this.tickLabelColor,
    required this.axisThickness,
    required this.majorTickThickness,
    required this.minorTickThickness,
    required this.minorTickColor,
    required this.labelStyleByLOD,
    required this.labelStride,
    required this.debug,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    // Draw base axis line
    final axisPaint = Paint()
      ..color = timelineColor
      ..strokeWidth = axisThickness;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), axisPaint);

    // Delegate tick generation and label selection to the tick manager.
    // The manager selects a time unit (LOD) based on current zoom so that
    // consecutive major ticks are roughly a target spacing in pixels.
    final scale = basePxPerMs * zoom;
    final leftMs = -panOffset / scale;
    // Generate ticks (minor + major) and an optional grid for the viewport
    final tickManager = _PackageTickManager.instance
      ..initialize(
        axisColor: timelineColor,
        labelColor: tickLabelColor,
        minorColor: (minorTickColor ?? timelineColor.withOpacity(0.7)),
        majorThickness: majorTickThickness,
        minorThickness: minorTickThickness,
      )
      ..setBasePixelsPerMs(basePxPerMs);
    final ticks = tickManager.generateTicks(zoom, panOffset, size);
    // Grid
    tickManager.renderGrid(canvas, zoom, panOffset, size);
    // Axis ticks + labels (labels are attached to major ticks only)
    tickManager.renderTicks(
      canvas: canvas,
      ticks: ticks,
      centerY: centerY,
      size: size,
      labelStride: labelStride,
      styleByLOD: labelStyleByLOD,
    );

    // Events
    // Draw event markers
    final marker = Paint()..color = eventColor;
    for (final ev in events) {
      final x = (ev.date.millisecondsSinceEpoch.toDouble() - leftMs) * scale;
      canvas.drawCircle(Offset(x, centerY), 6, marker);
    }
  }

  // no-op

  @override
  bool shouldRepaint(covariant _Painter old) =>
      old.events != events || old.zoom != zoom || old.panOffset != panOffset;
}

// Minimal, namespaced copy of the performant tick manager for the package
class _PackageTickManager {
  _PackageTickManager._();
  static final _PackageTickManager instance = _PackageTickManager._();

  final List<_PkgTick> _pool = [];
  final List<_PkgTick> _active = [];
  final Map<String, TextPainter> _tpCache = {};
  late Paint _major, _minor, _grid;
  bool _init = false;
  double _basePxPerMs = 0.00002;
  Color _labelColor = const Color(0xFF666666);

  void initialize({
    required Color axisColor,
    required Color labelColor,
    required Color minorColor,
    required double majorThickness,
    required double minorThickness,
  }) {
    if (!_init) {
      _major = Paint()
        ..color = axisColor
        ..strokeWidth = majorThickness;
      _minor = Paint()
        ..color = minorColor
        ..strokeWidth = minorThickness;
      _grid = Paint()
        ..color = axisColor.withOpacity(0.25)
        ..strokeWidth = 0.5;
      _labelColor = labelColor;
      _init = true;
    } else {
      // Update mutable properties at runtime
      _major
        ..color = axisColor
        ..strokeWidth = majorThickness;
      _minor
        ..color = minorColor
        ..strokeWidth = minorThickness;
      _labelColor = labelColor;
    }
  }

  void setBasePixelsPerMs(double v) => _basePxPerMs = v;

  /// Core of tick computation.
  ///
  /// LOD (time unit) selection:
  /// - Choose the first candidate unit whose major-tick spacing in pixels
  ///   (pxPerMs * unit.majorMs) is >= targetPx (roughly 90px by default),
  ///   so consecutive major ticks are nicely spaced for readability.
  /// - If none match (very zoomed out), fall back to the coarsest candidate
  ///   so at least some labels remain visible.
  ///
  /// Tick generation:
  /// - Minor ticks: every unit.minorMs within the viewport with a small height.
  /// - Major ticks: every unit.majorMs; these receive labels using the unit's
  ///   formatter. Labels are centered under the tick and culled if off-screen.
  List<_PkgTick> generateTicks(double zoom, double pan, Size size) {
    for (final t in _active) _pool.add(t);
    _active.clear();
    final scale = _basePxPerMs * zoom;
    final leftMs = -pan / scale;
    final rightMs = leftMs + size.width / scale;

    final unit = _pickUnit(scale);

    double ceilTo(double v, double step) {
      final m = v % step;
      return m == 0 ? v : v + (step - m);
    }

    // Minor ticks at fixed step for the chosen unit
    final firstMinor = ceilTo(leftMs, unit.minorMs);
    for (double t = firstMinor; t <= rightMs; t += unit.minorMs) {
      final x = (t - leftMs) * scale;
      if (x < -50 || x > size.width + 50) continue;
      _active.add(_get().set(t, x, false, '', 8));
    }
    // Major ticks at fixed step for the chosen unit
    final firstMajor = ceilTo(leftMs, unit.majorMs);
    for (double t = firstMajor; t <= rightMs; t += unit.majorMs) {
      final x = (t - leftMs) * scale;
      if (x < -100 || x > size.width + 100) continue;
      final label = unit.label(
        DateTime.fromMillisecondsSinceEpoch(t.toInt(), isUtc: true),
      );
      _active.add(_get().set(t, x, true, label, 16));
    }
    return _active;
  }

  void renderGrid(Canvas canvas, double zoom, double pan, Size size) {
    final scale = _basePxPerMs * zoom;
    final leftMs = -pan / scale;
    final rightMs = leftMs + size.width / scale;
    final unit = _pickUnit(scale);
    double ceilTo(double v, double step) {
      final m = v % step;
      return m == 0 ? v : v + (step - m);
    }

    final firstMajor = ceilTo(leftMs, unit.majorMs);
    for (double t = firstMajor; t <= rightMs; t += unit.majorMs) {
      final x = (t - leftMs) * scale;
      if (x >= -10 && x <= size.width + 10) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), _grid);
      }
    }
  }

  void renderTicks({
    required Canvas canvas,
    required List<_PkgTick> ticks,
    required double centerY,
    required Size size,
    int labelStride = 1,
    Map<TimeScaleLOD, TextStyle>? styleByLOD,
  }) {
    int majorIndex = 0;
    for (final tick in ticks) {
      final p = tick.isMajor ? _major : _minor;
      canvas.drawLine(
        Offset(tick.x, centerY - tick.h),
        Offset(tick.x, centerY + tick.h),
        p,
      );
      if (tick.isMajor && tick.label.isNotEmpty) {
        if (labelStride > 1 && (majorIndex++ % labelStride != 0)) continue;
        TextStyle style = TextStyle(
          color: _labelColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
        // Apply per-LOD style if provided
        if (styleByLOD != null) {
          final lod = _inferLODFromLabel(tick.label);
          final override = styleByLOD[lod];
          if (override != null) style = override;
        }
        final tp = _tp('${tick.label}_${_labelColor.value}_12_5', style);
        tp.layout();
        final tx = tick.x - tp.width / 2;
        if (tx <= size.width && tx + tp.width >= 0) {
          tp.paint(canvas, Offset(tx, centerY + tick.h + 4));
        }
      }
    }
  }

  // Heuristic: infer LOD from label formatting to select a style override
  TimeScaleLOD _inferLODFromLabel(String label) {
    if (label.endsWith(':00')) return TimeScaleLOD.hour;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(label)) return TimeScaleLOD.day;
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(label)) return TimeScaleLOD.month;
    if (RegExp(r'^\d{4}$').hasMatch(label)) return TimeScaleLOD.year;
    if (label.endsWith('0s')) return TimeScaleLOD.decade;
    if (label.endsWith('00s')) return TimeScaleLOD.century;
    return TimeScaleLOD.millennium;
  }

  TextPainter _tp(String key, TextStyle s) {
    if (!_tpCache.containsKey(key)) {
      _tpCache[key] = TextPainter(
        text: TextSpan(text: key.split('_').first, style: s),
        textDirection: TextDirection.ltr,
      );
    } else {
      _tpCache[key]!.text = TextSpan(text: key.split('_').first, style: s);
    }
    return _tpCache[key]!;
  }

  _PkgTick _get() => _pool.isNotEmpty ? _pool.removeLast() : _PkgTick();

  /// Selects the time unit (LOD) for ticks based on zoom.
  ///
  /// The goal is to make the distance between consecutive major ticks close to
  /// `targetPx` (about 90 px). We iterate from fine→coarse units and return the
  /// first whose major spacing in pixels is >= target. If nothing matches, we
  /// return the coarsest unit so labels still appear when fully zoomed out.
  _PkgUnit _pickUnit(double pxPerMs) {
    const targetPx = 90.0;
    _PkgUnit mk(double maj, double min, String Function(DateTime) fmt) =>
        _PkgUnit(maj, min, fmt);
    final hour = 3600e3,
        day = 24 * 3600e3,
        week = 7 * day,
        month = 30 * day,
        year = 365 * day,
        dec = 10 * year,
        cen = 100 * year,
        mil = 1000 * year;
    final cand = <_PkgUnit>[
      mk(hour, hour / 6, (d) => '${d.hour.toString().padLeft(2, '0')}:00'),
      mk(
        day,
        hour,
        (d) =>
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      ),
      mk(
        week,
        day,
        (d) =>
            'W${(((DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(d.year, 1, 1)).inDays) / 7).floor() + 1)}',
      ),
      mk(month, week, (d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'),
      mk(year, month, (d) => '${d.year}'),
      mk(dec, year, (d) => '${(d.year ~/ 10) * 10}s'),
      mk(cen, dec, (d) => '${(d.year ~/ 100) * 100}s'),
      mk(mil, cen, (d) => '${(d.year ~/ 1000) * 1000}'),
    ];
    for (final u in cand) {
      if (pxPerMs * u.majorMs >= targetPx) return u;
    }
    return cand.first;
  }
}

class _PkgTick {
  late double tMs, x, h;
  late bool isMajor;
  late String label;
  _PkgTick set(double t, double xx, bool maj, String lbl, double hh) {
    tMs = t;
    x = xx;
    isMajor = maj;
    label = lbl;
    h = hh;
    return this;
  }
}

class _PkgUnit {
  final double majorMs, minorMs;
  final String Function(DateTime) label;
  _PkgUnit(this.majorMs, this.minorMs, this.label);
}
