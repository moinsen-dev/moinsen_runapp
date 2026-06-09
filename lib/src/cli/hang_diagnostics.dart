import 'dart:async';

import 'package:vm_service/vm_service.dart';

/// Collects "why is this app stuck?" diagnostics from a running isolate.
///
/// Combines several VM Service signals that together reveal async deadlocks,
/// microtask floods, and timer starvation:
///
/// * **Isolate state** — `runnable` plus the last pause event. A non-runnable
///   isolate or a `PauseException`/`PauseBreakpoint` pauseEvent explains a
///   frozen UI immediately.
/// * **Current stack** — `getStack` works *without* pausing the isolate and
///   returns both the synchronous frames and the asynchronous awaiter chain
///   (`asyncCausalFrames`). This is the single most useful "where is it hung"
///   signal.
/// * **Queued microtasks** — `getQueuedMicrotasks` (vm_service ≥ 15.0.1). A
///   deep queue is the signature of a microtask flood. Gated behind the VM
///   flag `--profile-microtasks`; when unavailable we degrade gracefully with
///   an actionable note instead of throwing.
/// * **Overdue timers** — briefly listens on the `Timer` stream for
///   `TimerSignificantlyOverdue` events (vm_service ≥ 15.0.2 / 15.1.0), which
///   fire when the event loop is too busy to service timers on time.
///
/// Never throws for the optional signals — partial diagnostics are more useful
/// than a hard failure. Only a dead [service]/[isolateId] propagates.
Future<Map<String, dynamic>> collectHangDiagnostics(
  VmService service,
  String isolateId, {
  Duration timerWatch = const Duration(milliseconds: 1500),
  int stackLimit = 16,
  int sampleLimit = 10,
}) async {
  final result = <String, dynamic>{'isolateId': isolateId};

  // 1. Isolate liveness + pause state.
  try {
    final isolate = await service.getIsolate(isolateId);
    result['runnable'] = isolate.runnable;
    result['pauseEvent'] = isolate.pauseEvent?.kind;
    result['livePorts'] = isolate.livePorts;
  } on Object catch (e) {
    result['isolateError'] = e.toString();
  }

  // 2. Current execution + async awaiter chain (no pause required).
  try {
    final stack = await service.getStack(isolateId, limit: stackLimit);
    result['stack'] = {
      'frameCount': stack.frames?.length ?? 0,
      'topFrames': _labelFrames(stack.frames, stackLimit),
      'asyncAwaiterChain': _labelFrames(stack.asyncCausalFrames, stackLimit),
    };
  } on Object catch (e) {
    result['stackError'] = e.toString();
  }

  // 3. Queued microtasks (depth = async backlog). Gracefully degrades.
  result['microtasks'] = await _collectMicrotasks(
    service,
    isolateId,
    sampleLimit,
  );

  // 4. Overdue timers — event-loop starvation signal.
  if (timerWatch > Duration.zero) {
    result['overdueTimers'] = await _watchOverdueTimers(service, timerWatch);
  }

  return result;
}

Future<Map<String, dynamic>> _collectMicrotasks(
  VmService service,
  String isolateId,
  int sampleLimit,
) async {
  try {
    final queue = await service.getQueuedMicrotasks(isolateId);
    final tasks = queue.microtasks ?? const <Microtask>[];
    return {
      'available': true,
      'count': tasks.length,
      'sample': tasks
          .take(sampleLimit)
          .map(
            (m) => {
              'id': m.id,
              'enqueuedAt': (m.stackTrace ?? '')
                  .split('\n')
                  .firstWhere((l) => l.trim().isNotEmpty, orElse: () => ''),
            },
          )
          .toList(),
    };
  } on RPCError catch (e) {
    // 100 = "Feature is disabled" (VM not started with --profile-microtasks).
    // 115 = "Cannot get queued microtasks" (unhandled exception in isolate).
    final note = e.code == 100
        ? 'Microtask profiling is off. Restart the app with the VM flag '
              '--profile-microtasks (e.g. '
              '`flutter run --dart-vm-flags=--profile-microtasks`) to inspect '
              'the microtask queue.'
        : 'Unavailable: ${e.message} (code ${e.code}).';
    return {'available': false, 'note': note};
  } on Object catch (e) {
    return {'available': false, 'note': 'Unavailable: $e'};
  }
}

Future<Map<String, dynamic>> _watchOverdueTimers(
  VmService service,
  Duration window,
) async {
  final events = <Map<String, dynamic>>[];
  StreamSubscription<Event>? sub;
  var subscribed = false;
  try {
    await service.streamListen('Timer');
    subscribed = true;
    sub = service.onTimerEvent.listen((event) {
      if (event.kind == EventKind.kTimerSignificantlyOverdue) {
        events.add({'timestamp': event.timestamp, 'kind': event.kind});
      }
    });
    await Future<void>.delayed(window);
  } on Object catch (e) {
    return {'windowMs': window.inMilliseconds, 'error': e.toString()};
  } finally {
    await sub?.cancel();
    if (subscribed) {
      try {
        await service.streamCancel('Timer');
      } on Object {
        // Stream may already be torn down — ignore.
      }
    }
  }
  return {
    'windowMs': window.inMilliseconds,
    'count': events.length,
    'events': events,
  };
}

/// Render frames as readable `function (uri:line)` labels, marking the async
/// gaps that separate the awaiter chain.
List<String> _labelFrames(List<Frame>? frames, int limit) {
  if (frames == null) return const [];
  return frames.take(limit).map(_frameLabel).toList();
}

String _frameLabel(Frame frame) {
  if (frame.kind == FrameKind.kAsyncSuspensionMarker) {
    return '<asynchronous gap>';
  }
  final fn = frame.function?.name ?? frame.code?.name ?? '<unknown>';
  final loc = frame.location;
  final uri = loc?.script?.uri;
  if (uri == null) return fn;
  final line = loc?.line;
  return line == null ? '$fn ($uri)' : '$fn ($uri:$line)';
}
