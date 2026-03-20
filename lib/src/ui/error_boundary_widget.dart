import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moinsen_runapp/src/config.dart';
import 'package:moinsen_runapp/src/error_observer.dart';
import 'package:moinsen_runapp/src/ui/debug_error_screen.dart';
import 'package:moinsen_runapp/src/ui/release/release_error_screen.dart';

/// Wraps the user's app widget and manages the error overlay.
///
/// Uses a [Stack] so the error screen is a **sibling** of the app,
/// not a descendant. If the app's widget tree fails to build,
/// Flutter replaces only that child with [ErrorWidget] — the error
/// screen sibling still renders independently. This guarantees
/// the app is never blocked from starting.
class ErrorBoundaryWidget extends StatefulWidget {
  const ErrorBoundaryWidget({
    required this.child,
    required this.observer,
    required this.config,
    super.key,
  });

  final Widget child;
  final ErrorObserver observer;
  final RunAppConfig config;

  @override
  State<ErrorBoundaryWidget> createState() => _ErrorBoundaryWidgetState();
}

class _ErrorBoundaryWidgetState extends State<ErrorBoundaryWidget> {
  bool _dismissed = false;

  void _dismiss() {
    widget.observer.resume();
    setState(() => _dismissed = true);
  }

  void _clearAndRetry() {
    widget.observer.clearErrors();
    widget.observer.resume();
    setState(() => _dismissed = false);
  }

  @override
  Widget build(BuildContext context) {
    // Stack renders children independently — if the app child
    // throws during build, the error screen sibling still works.
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        // Bottom layer: the actual app — always mounted.
        widget.child,

        // Top layer: reactive error overlay.
        ListenableBuilder(
          listenable: widget.observer,
          builder: (context, _) {
            if (!widget.observer.hasErrors || _dismissed) {
              return const SizedBox.shrink();
            }
            // Freeze capture — the user is looking at the errors,
            // no value in counting more cascading duplicates.
            widget.observer.pause();
            return _buildErrorScreen(context);
          },
        ),
      ],
    );
  }

  Widget _buildErrorScreen(BuildContext context) {
    if (kDebugMode) {
      if (widget.config.debugScreenBuilder != null) {
        return widget.config.debugScreenBuilder!(
          context,
          widget.observer.errors,
        );
      }
      return DebugErrorScreen(
        observer: widget.observer,
        onDismiss: _dismiss,
        onClear: _clearAndRetry,
      );
    }

    if (widget.config.releaseScreenBuilder != null) {
      return widget.config.releaseScreenBuilder!(
        context,
        widget.observer.errors,
      );
    }
    return ReleaseErrorScreen(
      variant: widget.config.releaseScreenVariant,
      observer: widget.observer,
      onRetry: _clearAndRetry,
    );
  }
}
