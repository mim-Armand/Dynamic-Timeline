// This file is extracted from the app's timeline implementation and minimally
// refactored to compile inside a package. Public API remains similar.

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef TimelineEventTap = void Function(TimelineEvent event);

// LOD values used for tick generation/label styling. `all` is a special key
// that can be used in `labelStyleByLOD` to apply a style to every LOD, and a
// more granular LOD (e.g. `year`) can still override it.
enum TimeScaleLOD {
  all,
  hour,
  day,
  week,
  month,
  year,
  decade,
  century,
  millennium,
}

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
  // Orientation of the time axis. Horizontal by default.
  final Axis orientation;
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
    this.orientation = Axis.horizontal,
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
  double _lastViewExtent = 0; // length along the main axis
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
          case TimeScaleLOD.all:
            // Treat the global style key as the finest unit for zoom extent
            // calculations. Users should pass concrete LODs (hour..millennium)
            // for minZoomLOD/maxZoomLOD; this just makes the switch exhaustive.
            return 3600e3;
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
            final bool vertical = widget.orientation == Axis.vertical;
            // Determine paint size based on orientation. `height` is treated
            // as the cross-axis thickness in both orientations. Guard against
            // unbounded constraints by falling back to `height`.
            final double resolvedMaxWidth =
                cts.maxWidth.isFinite ? cts.maxWidth : widget.height;
            final double resolvedMaxHeight =
                cts.maxHeight.isFinite ? cts.maxHeight : widget.height;
            final double paintWidth =
                vertical ? widget.height : resolvedMaxWidth;
            final double paintHeight =
                vertical ? resolvedMaxHeight : widget.height;
            final double viewExtent = vertical ? paintHeight : paintWidth;
            _lastViewExtent = viewExtent.isFinite ? viewExtent : 0;
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
                    final double anchor =
                        vertical ? e.localPosition.dy : e.localPosition.dx;
                    _zoomAnchored(factor, anchor);
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
                    Size(paintWidth, paintHeight),
                  );
                  if (hit != null) widget.onEventTap!(hit);
                },
                onScaleUpdate: (details) {
                  final box = context.findRenderObject() as RenderBox;
                  final local = box.globalToLocal(details.focalPoint);
                  if (details.scale != 1.0) {
                    // Pinch zoom anchored at focal point
                    final double anchor = vertical ? local.dy : local.dx;
                    _zoomAnchored(details.scale, anchor);
                  } else {
                    // Trackpad cross-axis pan interpreted as zoom gesture
                    final double mainDelta = vertical
                        ? details.focalPointDelta.dy
                        : details.focalPointDelta.dx;
                    final double crossDelta = vertical
                        ? details.focalPointDelta.dx
                        : details.focalPointDelta.dy;
                    final double absMain = mainDelta.abs();
                    final double absCross = crossDelta.abs();
                    if (absCross > absMain && crossDelta != 0) {
                      final factor = math.pow(1.0015, -crossDelta).toDouble();
                      final double anchor = vertical ? local.dy : local.dx;
                      _zoomAnchored(factor, anchor);
                    } else {
                      _panOffset += mainDelta;
                      setState(() {});
                    }
                  }
                },
                child: SizedBox(
                  width: paintWidth,
                  height: paintHeight,
                  child: ClipRect(
                    child: CustomPaint(
                      size: Size(paintWidth, paintHeight),
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
                        vertical: vertical,
                      ),
                    ),
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
    if (_lastViewExtent <= 0) return;
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
    final leftMs = targetCenterMs - (_lastViewExtent / 2) / scale;
    setState(() {
      _panOffset = -leftMs * scale;
    });
  }

  TimelineEvent? _hitTestEvent(Offset p, Size size) {
    final base = widget.basePixelsPerMillisecond;
    final scale = base * _zoom;
    final leftMs = -_panOffset / scale;
    final bool vertical = widget.orientation == Axis.vertical;
    // naive marker hit test: circle radius 8 at axis center
    final axisCenter = vertical ? size.width * 0.5 : size.height * 0.5;
    for (final ev in widget.events) {
      final mainPos =
          (ev.date.millisecondsSinceEpoch.toDouble() - leftMs) * scale;
      final Offset marker =
          vertical ? Offset(axisCenter, mainPos) : Offset(mainPos, axisCenter);
      if ((p - marker).distance <= 10) return ev;
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
  final bool vertical;
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
    required this.vertical,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerCross = vertical ? size.width / 2 : size.height / 2;
    // Draw base axis line
    final axisPaint = Paint()
      ..color = timelineColor
      ..strokeWidth = axisThickness;
    if (vertical) {
      canvas.drawLine(
        Offset(centerCross, 0),
        Offset(centerCross, size.height),
        axisPaint,
      );
    } else {
      canvas.drawLine(
        Offset(0, centerCross),
        Offset(size.width, centerCross),
        axisPaint,
      );
    }

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
    final ticks = tickManager.generateTicks(
      zoom,
      panOffset,
      size,
      vertical: vertical,
    );
    // Grid
    tickManager.renderGrid(
      canvas,
      zoom,
      panOffset,
      size,
      vertical: vertical,
    );
    // Axis ticks + labels (labels are attached to major ticks only)
    tickManager.renderTicks(
      canvas: canvas,
      ticks: ticks,
      centerY: centerCross,
      size: size,
      labelStride: labelStride,
      styleByLOD: labelStyleByLOD,
      vertical: vertical,
    );

    // Debug overlay with diagnostics about LOD selection and label visibility
    if (debug) {
      final diag = tickManager.diagnostics;
      if (diag != null) {
        final lines = <String>[
          'LOD: ${diag.lod.name}',
          'px/ms: ${diag.pxPerMs.toStringAsFixed(6)}  target: ${diag.targetPx.toStringAsFixed(0)}px',
          'major: ${diag.majorMs ~/ 1000}s (${diag.majorPx.toStringAsFixed(1)} px)  minor: ${diag.minorMs ~/ 1000}s (${diag.minorPx.toStringAsFixed(1)} px)',
          'majors in view: ${diag.numMajor}  minors: ${diag.numMinor}',
          'labels drawn: ${diag.labelsPainted}  skippedByStride: ${diag.labelsDroppedByStride}  stride: $labelStride',
        ];
        final text = lines.join('\n');
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: Colors.black.withOpacity(0.85),
              fontSize: 12,
              height: 1.2,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width - 8);
        // Background for readability
        final bg = Paint()..color = Colors.white.withOpacity(0.7);
        final rect = Rect.fromLTWH(4, 4, tp.width + 8, tp.height + 8);
        canvas.drawRect(rect, bg);
        tp.paint(canvas, const Offset(8, 8));
      }
    }

    // Events
    // Draw event markers
    final marker = Paint()..color = eventColor;
    for (final ev in events) {
      final mainPos =
          (ev.date.millisecondsSinceEpoch.toDouble() - leftMs) * scale;
      final Offset pos = vertical
          ? Offset(centerCross, mainPos)
          : Offset(mainPos, centerCross);
      canvas.drawCircle(pos, 6, marker);
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
  _Diagnostics? diagnostics;
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
  List<_PkgTick> generateTicks(
    double zoom,
    double pan,
    Size size, {
    bool vertical = false,
  }) {
    for (final t in _active) _pool.add(t);
    _active.clear();
    final scale = _basePxPerMs * zoom;
    final leftMs = -pan / scale;
    final mainExtent = vertical ? size.height : size.width;
    final rightMs = leftMs + mainExtent / scale;

    final unit = _pickUnit(scale);

    double ceilTo(double v, double step) {
      final m = v % step;
      return m == 0 ? v : v + (step - m);
    }

    // Initialize diagnostics for this frame
    diagnostics = _Diagnostics(
      lod: unit.lod,
      pxPerMs: scale,
      targetPx: 90.0,
      majorMs: unit.majorMs,
      minorMs: unit.minorMs,
    );
    // Minor ticks at fixed step for the chosen unit
    final firstMinor = ceilTo(leftMs, unit.minorMs);
    for (double t = firstMinor; t <= rightMs; t += unit.minorMs) {
      final pos = (t - leftMs) * scale;
      if (vertical) {
        if (pos < -50 || pos > size.height + 50) continue;
      } else {
        if (pos < -50 || pos > size.width + 50) continue;
      }
      _active.add(_get().set(t, pos, false, '', 8));
      diagnostics!.numMinor++;
    }
    // Major ticks at fixed step for the chosen unit
    final firstMajor = ceilTo(leftMs, unit.majorMs);
    for (double t = firstMajor; t <= rightMs; t += unit.majorMs) {
      final pos = (t - leftMs) * scale;
      if (vertical) {
        if (pos < -100 || pos > size.height + 100) continue;
      } else {
        if (pos < -100 || pos > size.width + 100) continue;
      }
      final label = unit.label(
        DateTime.fromMillisecondsSinceEpoch(t.toInt(), isUtc: true),
      );
      _active.add(_get().set(t, pos, true, label, 16));
      diagnostics!.numMajor++;
    }
    diagnostics!
      ..majorPx = unit.majorMs * scale
      ..minorPx = unit.minorMs * scale;
    return _active;
  }

  void renderGrid(Canvas canvas, double zoom, double pan, Size size,
      {bool vertical = false}) {
    final scale = _basePxPerMs * zoom;
    final leftMs = -pan / scale;
    final mainExtent = vertical ? size.height : size.width;
    final rightMs = leftMs + mainExtent / scale;
    final unit = _pickUnit(scale);
    double ceilTo(double v, double step) {
      final m = v % step;
      return m == 0 ? v : v + (step - m);
    }

    final firstMajor = ceilTo(leftMs, unit.majorMs);
    for (double t = firstMajor; t <= rightMs; t += unit.majorMs) {
      final pos = (t - leftMs) * scale;
      if (!vertical) {
        if (pos >= -10 && pos <= size.width + 10) {
          canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), _grid);
        }
      } else {
        if (pos >= -10 && pos <= size.height + 10) {
          canvas.drawLine(Offset(0, pos), Offset(size.width, pos), _grid);
        }
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
    bool vertical = false,
  }) {
    int majorIndex = 0;
    for (final tick in ticks) {
      final p = tick.isMajor ? _major : _minor;
      if (!vertical) {
        canvas.drawLine(
          Offset(tick.x, centerY - tick.h),
          Offset(tick.x, centerY + tick.h),
          p,
        );
      } else {
        canvas.drawLine(
          Offset(centerY - tick.h, tick.x),
          Offset(centerY + tick.h, tick.x),
          p,
        );
      }
      if (tick.isMajor && tick.label.isNotEmpty) {
        if (labelStride > 1 && (majorIndex++ % labelStride != 0)) {
          diagnostics?.labelsDroppedByStride++;
          continue;
        }
        TextStyle style = TextStyle(
          color: _labelColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        );
        // Apply per-LOD style if provided. `all` acts as a base style that
        // more specific LOD keys (e.g., `year`) can override.
        if (styleByLOD != null) {
          final lod = _inferLODFromLabel(tick.label);
          final baseForAll = styleByLOD[TimeScaleLOD.all];
          if (baseForAll != null) style = style.merge(baseForAll);
          final specific = styleByLOD[lod];
          if (specific != null) style = style.merge(specific);
        }
        final tp = _tp('${tick.label}_${_labelColor.value}_12_5', style);
        tp.layout();
        if (!vertical) {
          final tx = tick.x - tp.width / 2;
          if (tx <= size.width && tx + tp.width >= 0) {
            tp.paint(canvas, Offset(tx, centerY + tick.h + 4));
            diagnostics?.labelsPainted++;
          }
        } else {
          final ty = tick.x - tp.height / 2;
          final double labelX = centerY + tick.h + 4;
          if (ty <= size.height && ty + tp.height >= 0) {
            tp.paint(canvas, Offset(labelX, ty));
            diagnostics?.labelsPainted++;
          }
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
    _PkgUnit mk(
      double maj,
      double min,
      String Function(DateTime) fmt,
      TimeScaleLOD lod,
    ) =>
        _PkgUnit(maj, min, fmt, lod);
    final hour = 3600e3,
        day = 24 * 3600e3,
        week = 7 * day,
        month = 30 * day,
        year = 365 * day,
        dec = 10 * year,
        cen = 100 * year,
        mil = 1000 * year;
    final cand = <_PkgUnit>[
      mk(
        hour,
        hour / 6,
        (d) => '${d.hour.toString().padLeft(2, '0')}:00',
        TimeScaleLOD.hour,
      ),
      mk(
        day,
        hour,
        (d) =>
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        TimeScaleLOD.day,
      ),
      mk(
        week,
        day,
        (d) =>
            'W${(((DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(d.year, 1, 1)).inDays) / 7).floor() + 1)}',
        TimeScaleLOD.week,
      ),
      mk(
        month,
        week,
        (d) => '${d.year}-${d.month.toString().padLeft(2, '0')}',
        TimeScaleLOD.month,
      ),
      mk(year, month, (d) => '${d.year}', TimeScaleLOD.year),
      mk(dec, year, (d) => '${(d.year ~/ 10) * 10}s', TimeScaleLOD.decade),
      mk(cen, dec, (d) => '${(d.year ~/ 100) * 100}s', TimeScaleLOD.century),
      mk(
        mil,
        cen,
        (d) => '${(d.year ~/ 1000) * 1000}',
        TimeScaleLOD.millennium,
      ),
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
  final TimeScaleLOD lod;
  _PkgUnit(this.majorMs, this.minorMs, this.label, this.lod);
}

class _Diagnostics {
  final TimeScaleLOD lod;
  final double pxPerMs;
  final double targetPx;
  final double majorMs;
  final double minorMs;
  int numMajor = 0;
  int numMinor = 0;
  int labelsPainted = 0;
  int labelsDroppedByStride = 0;
  double majorPx = 0;
  double minorPx = 0;
  _Diagnostics({
    required this.lod,
    required this.pxPerMs,
    required this.targetPx,
    required this.majorMs,
    required this.minorMs,
  });
}
