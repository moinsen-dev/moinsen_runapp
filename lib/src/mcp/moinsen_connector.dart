import 'package:logging/logging.dart' as logging;
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Exception thrown when no connection is active.
class NotConnectedException implements Exception {
  const NotConnectedException();

  @override
  String toString() => 'Not connected to any app. Use the connect tool first.';
}

/// Exception thrown when a VM service extension call fails.
class MoinsenExtensionException implements Exception {
  MoinsenExtensionException(this.message, this.error);

  final String message;
  final String? error;

  @override
  String toString() {
    final buffer = StringBuffer(message);
    if (error != null) buffer.write('\nError: $error');
    return buffer.toString();
  }
}

/// Manages connection to a Flutter app's VM service and provides
/// typed access to all `ext.moinsen.*` extensions.
class MoinsenConnector {
  MoinsenConnector() : _logger = logging.Logger('MoinsenConnector');

  final logging.Logger _logger;
  VmService? _service;
  String? _isolateId;

  bool get isConnected => _service != null && _isolateId != null;

  // -- Connection management --

  Future<void> connect(String uri) async {
    if (isConnected) {
      _logger.warning('Already connected, disconnecting first');
      await disconnect();
    }

    _logger.info('Connecting to VM service at $uri');

    try {
      final wsUri = _toWebSocketUri(uri);
      _service = await vmServiceConnectUri(wsUri);
      _isolateId = await _findMoinsenIsolate();
      _logger.info('Connected to isolate: $_isolateId');
    } catch (err) {
      _service = null;
      _isolateId = null;
      _logger.severe('Failed to connect', err);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (_service != null) {
      _logger.info('Disconnecting');
      await _service!.dispose();
      _service = null;
      _isolateId = null;
    }
  }

  // -- Observation extensions --

  Future<Map<String, dynamic>> getErrors() => _callMoinsen('getErrors');

  Future<Map<String, dynamic>> clearErrors() => _callMoinsen('clearErrors');

  Future<Map<String, dynamic>> getInfo() => _callMoinsen('getInfo');

  Future<Map<String, dynamic>> getLogs() => _callMoinsen('getLogs');

  Future<Map<String, dynamic>> getPrompt() => _callMoinsen('getPrompt');

  Future<Map<String, dynamic>> getRoute() => _callMoinsen('getRoute');

  Future<Map<String, dynamic>> navigate(Map<String, String> params) =>
      _callMoinsen('navigate', params);

  Future<Map<String, dynamic>> getContext() => _callMoinsen('getContext');

  Future<Map<String, dynamic>> getDeviceInfo() => _callMoinsen('getDeviceInfo');

  Future<Map<String, dynamic>> getLifecycle() => _callMoinsen('getLifecycle');

  Future<Map<String, dynamic>> getNetwork() => _callMoinsen('getNetwork');

  Future<Map<String, dynamic>> getState([String? key]) {
    final params = <String, String>{};
    if (key != null) params['key'] = key;
    return _callMoinsen('getState', params);
  }

  Future<Map<String, dynamic>> screenshot({double? scale}) => _callMoinsen(
    'screenshot',
    {if (scale != null) 'scale': scale.toString()},
  );

  // -- Interaction extensions --

  Future<Map<String, dynamic>> getInteractiveElements() =>
      _callMoinsen('getInteractiveElements');

  Future<Map<String, dynamic>> tap(Map<String, String> params) =>
      _callMoinsen('tap', params);

  Future<Map<String, dynamic>> enterText(Map<String, String> params) =>
      _callMoinsen('enterText', params);

  Future<Map<String, dynamic>> scrollTo(Map<String, String> params) =>
      _callMoinsen('scrollTo', params);

  // -- Dev extensions --

  Future<Map<String, dynamic>> hotReload() async {
    _ensureConnected();
    try {
      final sw = Stopwatch()..start();
      await _service!.callServiceExtension(
        '_flutter.hotReload',
        isolateId: _isolateId,
      );
      sw.stop();
      return {'success': true, 'duration_ms': sw.elapsedMilliseconds};
    } on Object catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> hotRestart() async {
    _ensureConnected();
    try {
      final sw = Stopwatch()..start();
      await _service!.callServiceExtension(
        '_flutter.hotRestart',
        isolateId: _isolateId,
      );
      sw.stop();
      return {'success': true, 'duration_ms': sw.elapsedMilliseconds};
    } on Object catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // -- Internal --

  void _ensureConnected() {
    if (!isConnected) throw const NotConnectedException();
  }

  Future<Map<String, dynamic>> _callMoinsen(
    String name, [
    Map<String, String>? params,
  ]) async {
    _ensureConnected();
    _logger.fine('Calling ext.moinsen.$name');

    try {
      final response = await _service!.callServiceExtension(
        'ext.moinsen.$name',
        isolateId: _isolateId,
        args: params,
      );

      final json = response.json;
      if (json == null) {
        throw MoinsenExtensionException(
          'ext.moinsen.$name returned null',
          null,
        );
      }
      return Map<String, dynamic>.from(json);
    } on Object catch (e) {
      if (e is MoinsenExtensionException || e is NotConnectedException) {
        rethrow;
      }
      _logger.severe('Error calling ext.moinsen.$name', e);
      rethrow;
    }
  }

  /// Finds the first isolate with moinsen extensions.
  Future<String> _findMoinsenIsolate() async {
    final vm = await _service!.getVM();
    final isolates = vm.isolates;
    if (isolates == null || isolates.isEmpty) {
      throw Exception('No isolates found');
    }

    for (final ref in isolates) {
      if (ref.id == null) continue;
      try {
        final isolate = await _service!.getIsolate(ref.id!);
        final hasMoinsen =
            isolate.extensionRPCs?.any(
              (ext) => ext == 'ext.moinsen.getErrors',
            ) ??
            false;
        if (hasMoinsen) return ref.id!;
      } on Object catch (e) {
        _logger.warning('Failed to check isolate ${ref.id}', e);
        continue;
      }
    }

    throw Exception(
      'No isolate with ext.moinsen.getErrors found. '
      'Ensure the app uses moinsenRunApp().',
    );
  }

  /// Convert HTTP/HTTPS URI to WebSocket URI.
  static String _toWebSocketUri(String uri) {
    var result = uri;
    if (result.startsWith('https://')) {
      result = 'wss://${result.substring(8)}';
    } else if (result.startsWith('http://')) {
      result = 'ws://${result.substring(7)}';
    }
    if (!result.endsWith('/ws')) {
      result = result.endsWith('/') ? '${result}ws' : '$result/ws';
    }
    return result;
  }
}
