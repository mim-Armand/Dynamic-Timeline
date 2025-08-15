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

