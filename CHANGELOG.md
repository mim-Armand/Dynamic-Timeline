## 0.1.0

- Initial release of `interactive_timeline`
- Anchored zoom (wheel/trackpad/pinch)
- Smooth horizontal panning
- Auto-LOD ticks (hours → months → years → decades → centuries → millennia)
- Event markers with tap callback
- Per-LOD label styles and global `TimeScaleLOD.all` base style

## 0.2.0

- feat: Customizable event markers
  - New `TimelineEvent` fields: `markerOffset`, `markerScale`.
  - New `TimelineWidget` options:
    - `eventMarkerBuilder(BuildContext, TimelineEvent, EventMarkerInfo)` to render per-event widgets at precise timeline positions.
    - `eventMarkerPainter(Canvas, TimelineEvent, EventMarkerInfo)` to draw custom shapes on the canvas.
    - `eventMarkerOffset`, `eventMarkerScale` defaults applied when per-event override is not provided.
    - `showDefaultEventMarker` flag to hide built-in dot markers when using custom widgets/painters.
  - Clicking custom widget markers triggers `onEventTap`.

- feat: Customizable ticks
  - New `tickPainter(Canvas, TickInfo, TickDrawContext)` to fully customize tick shapes.
  - New `tickOffset`, `tickScale` for tick positioning and scaling.

- feat: Tick label font selection
  - New `tickLabelStyle` base style for all labels (merged before `labelStyleByLOD`).
  - New `tickLabelFontFamily` to force a specific font family.

- docs: Updated README and site with examples for new APIs.

## 0.2.1

- Improvments: Added optional visual effects to the magnifying lenz effect
- fix: Replace deprecated Color API usages to support latest Flutter/Dart SDKs
  - `Color.withOpacity(x)` → `Color.withValues(alpha: x)`
  - `Color.value` (for cache keys) → `Color.toARGB32()`
- docs: Update README and site install snippets to latest version
- chore: Raise Flutter SDK constraint to `>=3.22.0` in `pubspec.yaml`

## 0.3.0

- feat: Duration spans and sticky labels
  - `TimelineEvent.endDate` draws a range between `date` and `endDate`.
  - Sticky alignment for ranged events: `labelAlign` (`left|right`) and `stickyLabel`.
  - Full-visibility clamping with width hint: `markerMainExtentPx` and widget-level
    `defaultStickyMarkerExtentPx`.
- feat: Stacking and crowd-control
  - Marker clustering with `markerClusterPx`, stacking with `markerMaxStackLayers` and `markerStackSpacing`.
  - Spans stack the same as markers; items beyond the max layers fade.
  - Global fade: `markerFadedOpacity`; per-event override: `TimelineEvent.fadedOpacity`.
  - Optional alternating lanes: `stackAlternateLanes` to stagger stacks above/below the axis.
- feat: Per-event colors
  - `TimelineEvent.spanColor`, `poleColor`, `markerColor`.
- feat: End poles for spans
  - `showSpanEndPoles` draws short lines from span ends to the axis in the span color/opacities.
  - `spanEndPoleThickness` controls stroke width (0.0 = hairline default).
- feat: Optional marker poles from axis to marker position
  - Global: `showEventPole`, `eventPoleThickness`, `eventPoleColor` (overridable per-event via `poleColor`).
- docs: Update README with new APIs and examples; update example app to showcase spans, stacking, alternating lanes, and span end poles.

