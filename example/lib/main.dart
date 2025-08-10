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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Interactive Timeline Demo'),
            const SizedBox(height: 12),
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
                minorTickColor: Colors.grey.shade500,
                labelStride: 1,
                labelStyleByLOD: const {
                  TimeScaleLOD.year: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  TimeScaleLOD.decade: TextStyle(fontSize: 12),
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
            const Text('Gestures:'),
            const Text(' - Mouse wheel/trackpad: zoom anchored under cursor'),
            const Text(' - Drag: pan horizontally'),
            const Text(' - Double-tap: center on events midpoint'),
          ],
        ),
      ),
    );
  }
}
