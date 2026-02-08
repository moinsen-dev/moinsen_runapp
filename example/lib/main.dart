import 'package:flutter/material.dart';
import 'package:moinsen_runapp/moinsen_runapp.dart';

void main() {
  moinsenRunApp(
    init: () async {
      // Simulate async initialization (Firebase, Hive, etc.)
      await Future<void>.delayed(const Duration(milliseconds: 500));
    },
    onError: (error, stackTrace) {
      // Forward to Sentry, Crashlytics, or your own backend:
      // Sentry.captureException(error, stackTrace: stackTrace);
      debugPrint('Error reported: $error');
    },
    config: const RunAppConfig(
      // Show the minimal error screen variant in release mode.
      releaseScreenVariant: ErrorScreenVariant.minimal,
      // Write errors to a log file on disk.
      logToFile: true,
    ),
    child: const ExampleApp(),
  );
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'moinsen_runapp Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('moinsen_runapp Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('The app is running with moinsen_runapp!'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Trigger a test error to see the error screen.
                throw Exception('Test error from button press');
              },
              child: const Text('Trigger Test Error'),
            ),
          ],
        ),
      ),
    );
  }
}
