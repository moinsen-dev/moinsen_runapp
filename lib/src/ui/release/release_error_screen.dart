import 'package:flutter/material.dart';
import 'package:moinsen_runapp/src/config.dart';
import 'package:moinsen_runapp/src/error_observer.dart';
import 'package:moinsen_runapp/src/ui/release/friendly_error_screen.dart';
import 'package:moinsen_runapp/src/ui/release/illustrated_error_screen.dart';
import 'package:moinsen_runapp/src/ui/release/minimal_error_screen.dart';

/// Routes to the correct release error screen variant.
class ReleaseErrorScreen extends StatelessWidget {
  const ReleaseErrorScreen({
    required this.variant,
    required this.observer,
    required this.onRetry,
    super.key,
  });

  final ErrorScreenVariant variant;
  final ErrorObserver observer;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      ErrorScreenVariant.friendly => FriendlyErrorScreen(
        onRetry: onRetry,
      ),
      ErrorScreenVariant.minimal => MinimalErrorScreen(
        onRetry: onRetry,
      ),
      ErrorScreenVariant.illustrated => IllustratedErrorScreen(
        onRetry: onRetry,
      ),
    };
  }
}
