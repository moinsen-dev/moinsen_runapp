import 'package:flutter/material.dart';
import 'package:moinsen_runapp/moinsen_runapp.dart';

void main() {
  moinsenRunApp(
    init: () async {
      // Simulate async initialization (Firebase, Hive, etc.)
      await Future<void>.delayed(const Duration(milliseconds: 500));
      moinsenLog('App initialized', source: 'init', level: 'info');
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
      // Configure log buffer size (default: 200).
      logBufferCapacity: 500,
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
      // Add the navigator observer for route tracking and navigation control.
      navigatorObservers: [MoinsenNavigatorObserver.instance],
      initialRoute: '/',
      routes: {
        '/': (_) => const HomePage(),
        '/details': (_) => const DetailsPage(),
      },
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
                moinsenLog('Navigating to details', source: 'home');
                Navigator.of(context).pushNamed('/details');
              },
              child: const Text('Go to Details'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                moinsenLog('User tapped log button', source: 'home');
              },
              child: const Text('Log a Message'),
            ),
            const SizedBox(height: 12),
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

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    moinsenLog('Details page built', source: 'details', level: 'debug');
    return Scaffold(
      appBar: AppBar(title: const Text('Details')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('This is the details page.'),
            const SizedBox(height: 16),
            const Text(
              'Try "moinsen_run route" to see navigation history,\n'
              'or "moinsen_run context" for a full LLM-ready report.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                moinsenLog('Navigating back from details', source: 'details');
                Navigator.of(context).pop();
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
