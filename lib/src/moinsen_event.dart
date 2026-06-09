import 'dart:developer' as developer;

/// The VM Service extension-event stream name that clients (DebugDeck, Claude
/// Code) subscribe to for PUSH updates, so they can stop polling. Listeners
/// filter the VM `Extension` stream by `extensionKind == moinsenEventKind`.
const moinsenEventKind = 'moinsen';

/// Emit a push event on the `moinsen` extension-event stream.
///
/// [kind] is the signal type — `error` | `route` | `lifecycle`. [payload] is a
/// small, JSON-safe map. Best-effort by design: posting must NEVER throw into
/// the host app's hot paths (an error catcher, a navigator callback, a
/// lifecycle transition), so everything is swallowed. When no VM Service is
/// attached (release build, plain `dart test`) this is a cheap no-op.
void emitMoinsenEvent(String kind, Map<String, Object?> payload) {
  try {
    developer.postEvent(moinsenEventKind, {
      'kind': kind,
      'at': DateTime.now().toUtc().toIso8601String(),
      'payload': payload,
    });
  } catch (_) {
    // Telemetry must never break the host app — drop silently.
  }
}
