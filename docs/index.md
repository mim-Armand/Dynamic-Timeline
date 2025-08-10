---
layout: home
title: Interactive Timeline for Flutter
---

# Interactive Timeline for Flutter

A performant, reusable horizontal timeline widget with:

- Anchored zoom (mouse wheel, trackpad, Magic Mouse, pinch)
- Smooth horizontal panning
- Auto-LOD ticks (hours → months → years → decades → centuries → millennia)
- Double-tap to center on events midpoint
- Event markers with tap callback

![Interactive timeline demo](assets/demo1.png)

[![pub package](https://img.shields.io/pub/v/interactive_timeline.svg)](https://pub.dev/packages/interactive_timeline)
Published on [pub.dev](https://pub.dev/packages/interactive_timeline).

## Install

Add the package from pub.dev to your `pubspec.yaml`:

```yaml
dependencies:
  interactive_timeline: ^0.1.0
```

## Quick Start

```dart
import 'package:interactive_timeline/interactive_timeline.dart';

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
    tickLabelColor: const Color(0xFF444444),
  ),
)
```

## Features

- Pooled tick manager for performance
- Per-LOD label styles and global `TimeScaleLOD.all`
- Simple API surface; bring your own theming

## Links

- Pub: https://pub.dev/packages/interactive_timeline
- Source: https://github.com/mim-Armand/Dynamic-Timeline

