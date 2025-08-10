# interactive_timeline

A performant, reusable horizontal timeline widget for Flutter with:

- Anchored zoom (mouse wheel, trackpad, Magic Mouse, pinch) around the cursor/focal point
- Smooth horizontal panning
- Auto-LOD ticks (hours → months → years → decades → centuries → millennia)
- Double-tap to center on events midpoint (or initial center)
- Event markers with tap callback
- Parent scroll suppression (prevents ancestor scrollables from hijacking gestures)

### Screenshot

![Interactive timeline demo](demo1.png)

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

1. Ensure `pubspec.yaml` has `name`, `description`, `version`, `homepage`, `repository`, `issue_tracker` and a proper SDK/Flutter constraint.
2. Include a `LICENSE` and `CHANGELOG.md` (both are present in this repo).
3. Add screenshots/GIFs to your README (optional but recommended).
4. Run:
   ```bash
   flutter pub publish --dry-run
   ```
   Fix any issues it reports.
5. Publish:
   ```bash
   flutter pub publish
   ```
6. Consumers can depend on it with:
   ```yaml
   dependencies:
     interactive_timeline: ^0.1.0
   ```

### Notes

- Anchored zoom keeps content under pointer fixed while zooming
- Pooled tick manager for performance
- Deep-time beyond `DateTime` possible with a custom epoch in future

---

## Contributing

- Fork the repo and create a feature branch from `main`.
- Development setup:
  - Flutter SDK 3.16+ (Dart 3)
  - Format and analyze before committing:
    - `dart format .`
    - `flutter analyze`
  - Run tests (add more as you contribute):
    - `flutter test`
  - Example app for manual testing:
    - `cd example && flutter run`
- Coding style: keep code clear and well-named; prefer small, readable functions. Follow the included `flutter_lints` rules.
- Commits: conventional messages are appreciated (feat:, fix:, docs:, chore:, refactor:, test:).
- Pull Requests: include a brief description, screenshots/GIFs if UI changes, and a changelog entry suggestion.

## Releasing and Publishing (pub.dev)

1. Update `CHANGELOG.md` with a new entry.
2. Bump `version:` in `pubspec.yaml` (semver).
3. Verify `README.md`, `LICENSE`, and `pubspec.yaml` metadata (`homepage`, `repository`, `issue_tracker`, `topics`).
4. Ensure screenshots referenced in the README (e.g., `demo1.png`) are checked in.
5. Dry run:
   ```bash
   dart format .
   flutter pub get
   flutter pub publish --dry-run
   ```
6. If clean, publish:
   ```bash
   flutter pub publish
   ```
7. Tag the release (optional but recommended):
   ```bash
   git tag v<version>
   git push --tags
   ```

## Republishing / Hotfixes

pub.dev does not allow re-uploading the same version. For any fix, bump the version (usually patch):

1. Update `CHANGELOG.md` (e.g., “0.1.1 – Fix label style precedence”).
2. Bump `version:` in `pubspec.yaml` to the next patch/minor.
3. Re-run the publish steps above (dry-run, then publish).
4. If you accidentally published a broken version, you can retract it from the pub.dev UI (Manage Versions → Retract). Consumers on that exact version will be warned.

### GitHub Pages website

- A minimal site is available under `docs/` and can be enabled via GitHub Pages (branch: `main`, folder: `/docs`).
- After it’s live, consider setting `homepage:` in `pubspec.yaml` to the Pages URL.
- If you prefer, move `demo1.png` into `docs/` (e.g., `docs/assets/`) and update links accordingly. Keeping it at the repo root also works for pub.dev README rendering.
