# interactive_timeline

A performant, reusable horizontal timeline widget for Flutter with:

- Anchored zoom (mouse wheel, trackpad, Magic Mouse, pinch) around the cursor/focal point
- Smooth horizontal panning
- Auto-LOD ticks (hours → months → years → decades → centuries → millennia)
- Double-tap to center on events midpoint (or initial center)
- Event markers with tap callback
- Parent scroll suppression (prevents ancestor scrollables from hijacking gestures)

### Installation (local path in a monorepo)

Add a path dependency in your app's `pubspec.yaml`:

```yaml
dependencies:
  interactive_timeline:
    path: packages/interactive_timeline
```

Import it:

```dart
import 'package:interactive_timeline/interactive_timeline.dart';
```

### Quick start

```dart
final now = DateTime.now().toUtc();
final events = <TimelineEvent>[
  TimelineEvent(date: now.subtract(const Duration(days: 365 * 2)), title: 'Two years ago'),
  TimelineEvent(date: now.subtract(const Duration(days: 30)), title: 'Last month'),
  TimelineEvent(date: now, title: 'Today'),
  TimelineEvent(date: now.add(const Duration(days: 30)), title: 'Next month'),
  TimelineEvent(date: now.add(const Duration(days: 365)), title: 'Next year'),
];

SizedBox(
  height: 140,
  child: TimelineWidget(
    height: 120,
    events: events,
    minZoomLOD: TimeScaleLOD.month,
    maxZoomLOD: TimeScaleLOD.century,
    tickLabelColor: const Color(0xFF444444),
    axisThickness: 2,
    majorTickThickness: 2,
    minorTickThickness: 1,
    minorTickColor: Colors.grey,
    labelStride: 1,
    labelStyleByLOD: const {
      TimeScaleLOD.year: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      TimeScaleLOD.decade: TextStyle(fontSize: 12),
    },
    onZoomChanged: (z) => debugPrint('zoom: $z'),
    onEventTap: (e) => debugPrint('Tapped: ${e.title}'),
  ),
)
```

### API (selected)

- Data: `events` (`TimelineEvent`)
- Size: `height`
- Zoom/scale: `initialZoom`, `minZoom`, `maxZoom`, `minZoomLOD`, `maxZoomLOD`, `basePixelsPerMillisecond`
- Styling: `timelineColor`, `eventColor`, `backgroundColor`, `tickLabelColor`, `axisThickness`, `majorTickThickness`, `minorTickThickness`, `minorTickColor`, `labelStride`, `labelStyleByLOD`
- Callbacks: `onZoomChanged(double)`, `onEventTap(TimelineEvent)`
- Behavior: anchored zoom, double-tap to center, suppress ancestor pointer events

### Example app (in this repo)

An example is included at `packages/interactive_timeline/example`. Run it directly:

```bash
cd example
flutter run
```

The example demonstrates:

- Anchored zoom via wheel/trackpad/pinch
- Horizontal panning
- Double-tap to center on events midpoint
- Event tap callback (shows a SnackBar)

### Publish to pub.dev

- Move package to its own repo root
- `pubspec.yaml`: set name/description/version; remove `publish_to: 'none'`; add `homepage`/`repository`/`issue_tracker`
- Add LICENSE, screenshots/GIFs, CHANGELOG.md
- `flutter pub publish --dry-run` then `flutter pub publish`
- Consumers: `interactive_timeline: ^0.1.0`

### Notes

- Anchored zoom keeps content under pointer fixed while zooming
- Pooled tick manager for performance
- Deep-time beyond `DateTime` possible with a custom epoch in future