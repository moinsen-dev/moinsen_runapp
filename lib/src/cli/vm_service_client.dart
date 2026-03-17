import 'dart:convert';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Client for communicating with a running Flutter app via VM Service.
///
/// Provides typed access to moinsen extensions and Flutter control
/// (hot reload, hot restart, widget tree).
class MoinsenVmClient {
  MoinsenVmClient._(this._service);

  final VmService _service;

  /// Connect to a running Flutter app's VM Service.
  static Future<MoinsenVmClient> connect(String uri) async {
    final wsUri = parseVmServiceUri(uri);
    final service = await vmServiceConnectUri(wsUri);
    return MoinsenVmClient._(service);
  }

  /// Call a moinsen extension (e.g. 'ext.moinsen.getErrors').
  Future<Map<String, dynamic>?> callMoinsen(String name) async {
    final isolateId = await _mainIsolateId();
    if (isolateId == null) return null;

    final response = await _service.callServiceExtension(
      name,
      isolateId: isolateId,
    );
    return _parseResponse(response);
  }

  /// Trigger hot reload on the main isolate.
  Future<Map<String, dynamic>> hotReload() async {
    final isolateId = await _mainIsolateId();
    if (isolateId == null) {
      return {'success': false, 'error': 'No main isolate found'};
    }

    try {
      final sw = Stopwatch()..start();
      await _service.callServiceExtension(
        '_flutter.hotReload',
        isolateId: isolateId,
      );
      sw.stop();
      return {'success': true, 'duration_ms': sw.elapsedMilliseconds};
    } on Object catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Trigger hot restart on the main isolate.
  Future<Map<String, dynamic>> hotRestart() async {
    final isolateId = await _mainIsolateId();
    if (isolateId == null) {
      return {'success': false, 'error': 'No main isolate found'};
    }

    try {
      final sw = Stopwatch()..start();
      await _service.callServiceExtension(
        '_flutter.hotRestart',
        isolateId: isolateId,
      );
      sw.stop();
      return {'success': true, 'duration_ms': sw.elapsedMilliseconds};
    } on Object catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get the widget tree dump via Flutter's built-in extension.
  Future<String?> getWidgetTree() async {
    final isolateId = await _mainIsolateId();
    if (isolateId == null) return null;

    try {
      final response = await _service.callServiceExtension(
        'ext.flutter.debugDumpApp',
        isolateId: isolateId,
      );
      return response.json?['data'] as String?;
    } on Object {
      return null;
    }
  }

  /// Call a moinsen extension with optional parameters.
  Future<Map<String, dynamic>?> callMoinsenWithParams(
    String name, {
    Map<String, String>? params,
  }) async {
    final isolateId = await _mainIsolateId();
    if (isolateId == null) return null;

    final response = await _service.callServiceExtension(
      name,
      isolateId: isolateId,
      args: params,
    );
    return _parseResponse(response);
  }

  /// Disconnect from the VM Service.
  Future<void> dispose() async {
    await _service.dispose();
  }

  /// Parse a VM Service extension response.
  ///
  /// The VM Service returns extension results in `response.json` as a
  /// decoded Map. Our extensions encode their data as a JSON string via
  /// `ServiceExtensionResponse.result(jsonEncode(...))`, which the VM
  /// Service then decodes back into a Map. So `response.json` already
  /// contains the parsed data directly.
  Map<String, dynamic>? _parseResponse(Response response) {
    final json = response.json;
    if (json == null) return null;

    // The VM Service protocol adds a 'type' key to every response.
    // Our extension data is everything else in the map.
    // In practice, response.json IS our parsed data (the VM Service
    // decodes the JSON string we pass to ServiceExtensionResponse.result).
    return Map<String, dynamic>.from(json);
  }

  Future<String?> _mainIsolateId() async {
    final vm = await _service.getVM();
    final isolates = vm.isolates;
    if (isolates == null || isolates.isEmpty) return null;
    return isolates.first.id;
  }
}

/// Convert a VM Service URI to a WebSocket URI.
///
/// Flutter run outputs HTTP URIs like `http://127.0.0.1:PORT/token/`.
/// The VM Service expects `ws://127.0.0.1:PORT/token/ws`.
String parseVmServiceUri(String uri) {
  var result = uri;

  // Convert http(s) to ws(s).
  if (result.startsWith('https://')) {
    result = 'wss://${result.substring(8)}';
  } else if (result.startsWith('http://')) {
    result = 'ws://${result.substring(7)}';
  }

  // Ensure path ends with /ws.
  if (!result.endsWith('/ws')) {
    if (result.endsWith('/')) {
      result = '${result}ws';
    } else {
      result = '$result/ws';
    }
  }

  return result;
}

/// Parse a JSON string from a VM Service extension response.
///
/// Returns the decoded object, or `null` if the input is null or invalid.
Object? parseExtensionResponse(String? json) {
  if (json == null) return null;
  try {
    return jsonDecode(json);
  } on Object {
    return null;
  }
}
