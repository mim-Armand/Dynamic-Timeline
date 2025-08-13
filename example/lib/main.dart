import 'package:flutter/material.dart';
import 'package:interactive_timeline/interactive_timeline.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final events = <TimelineEvent>[
      TimelineEvent(
        date: now.subtract(const Duration(days: 365 * 2)),
        title: 'Two years ago',
      ),
      TimelineEvent(
        date: now.subtract(const Duration(days: 30)),
        title: 'Last month',
      ),
      TimelineEvent(date: now, title: 'Today'),
      TimelineEvent(
        date: now.add(const Duration(days: 30)),
        title: 'Next month',
      ),
      TimelineEvent(
        date: now.add(const Duration(days: 365)),
        title: 'Next year',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Interactive Timeline Demo'),
              const SizedBox(height: 12),
              // Horizontal timeline (default)
              SizedBox(
                height: 160,
                child: TimelineWidget(
                  height: 120,
                  debugMode: false,
                  events: events,
                  minZoomLOD: TimeScaleLOD.month,
                  maxZoomLOD: TimeScaleLOD.century,
                  tickLabelColor: const Color(0xFF444444),
                  axisThickness: 2,
                  majorTickThickness: 2,
                  minorTickThickness: 1,
                  minorTickColor: Colors.grey.shade500,
                  labelStride: 1,
                  tickLabelStyle: const TextStyle(fontSize: 11),
                  tickLabelFontFamily: 'monospace',
                  labelStyleByLOD: const {
                    TimeScaleLOD.all: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                    TimeScaleLOD.year: TextStyle(fontSize: 14),
                  },
                  // Custom tick appearance via painter and offset/scale
                  tickOffset: const Offset(0, 0),
                  tickScale: 1.0,
                  tickPainter: (canvas, tick, ctx) {
                    final paint = Paint()
                      ..color = tick.isMajor ? ctx.axisColor : ctx.minorColor
                      ..strokeWidth = tick.isMajor ? 2 : 1;
                    if (!tick.vertical) {
                      final h = tick.height * ctx.tickScale;
                      final x = tick.positionMainAxis + ctx.tickOffset.dx;
                      final y = tick.centerCrossAxis + ctx.tickOffset.dy;
                      canvas.drawLine(
                        Offset(x, y - h),
                        Offset(x, y + h),
                        paint,
                      );
                    } else {
                      final h = tick.height * ctx.tickScale;
                      final x = tick.centerCrossAxis + ctx.tickOffset.dx;
                      final y = tick.positionMainAxis + ctx.tickOffset.dy;
                      canvas.drawLine(
                        Offset(x - h, y),
                        Offset(x + h, y),
                        paint,
                      );
                    }
                  },
                  // Event markers as widgets with offset and scale
                  eventMarkerOffset: const Offset(0, -12),
                  eventMarkerScale: 1.0,
                  showDefaultEventMarker: true,
                  eventMarkerBuilder: (ctx, event, info) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.place,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  onZoomChanged: (z) => debugPrint('zoom: $z'),
                  onEventTap: (e) => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Tapped: ${e.title} @ ${e.date.toIso8601String()}',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Vertical Timeline Demo'),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140, // constrain cross-axis thickness
                    height: 300, // desired main-axis extent
                    child: TimelineWidget(
                      height: 120, // cross-axis thickness used by painter
                      orientation: Axis.vertical,
                      debugMode: false,
                      events: events,
                      minZoomLOD: TimeScaleLOD.month,
                      maxZoomLOD: TimeScaleLOD.century,
                      tickLabelColor: const Color(0xFF444444),
                      axisThickness: 2,
                      majorTickThickness: 2,
                      minorTickThickness: 1,
                      minorTickColor: Colors.grey.shade500,
                      labelStride: 1,
                      labelStyleByLOD: const {
                        TimeScaleLOD.all: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      },
                      onZoomChanged: (z) => debugPrint('zoom: $z'),
                      onEventTap: (e) =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tapped: ${e.title} @ ${e.date.toIso8601String()}',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Tips:\n- Drag up/down to pan.\n- Use trackpad/mouse wheel to zoom anchored under the cursor.\n- Tap markers to show a SnackBar.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Gestures:'),
              const Text(' - Mouse wheel/trackpad: zoom anchored under cursor'),
              const Text(' - Drag: pan along the axis'),
              const Text(' - Double-tap: center on events midpoint'),
            ],
          ),
        ),
      ),
    );
  }
}
