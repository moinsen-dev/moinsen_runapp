import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

void main() {
  group('MoinsenVmClient', () {
    test('parseVmServiceUri extracts clean WebSocket URI', () {
      // Flutter run outputs URIs like:
      // "The Dart VM service is listening on http://127.0.0.1:12345/abc=/ws"
      // We need to convert http to ws for WebSocket connection.
      expect(
        parseVmServiceUri('http://127.0.0.1:12345/abc=/'),
        'ws://127.0.0.1:12345/abc=/ws',
      );
    });

    test('parseVmServiceUri handles ws:// URI as-is', () {
      expect(
        parseVmServiceUri('ws://127.0.0.1:12345/abc=/ws'),
        'ws://127.0.0.1:12345/abc=/ws',
      );
    });

    test('parseVmServiceUri appends ws if missing', () {
      expect(
        parseVmServiceUri('ws://127.0.0.1:12345/abc=/'),
        'ws://127.0.0.1:12345/abc=/ws',
      );
    });

    test('parseVmServiceUri handles https', () {
      expect(
        parseVmServiceUri('https://127.0.0.1:12345/abc=/'),
        'wss://127.0.0.1:12345/abc=/ws',
      );
    });

    test('parseExtensionResponse extracts JSON from response', () {
      // VM Service extension responses wrap the result in a
      // {"type":"_extensionType","method":"ext.moinsen.getErrors",
      //  "result": <actual JSON string>}
      // But callServiceExtension returns the result directly.
      const responseJson = '{"errors":[],"totalCount":0}';
      final parsed =
          parseExtensionResponse(responseJson)! as Map<String, dynamic>;

      expect(parsed['errors'], isEmpty);
      expect(parsed['totalCount'], 0);
    });

    test('parseExtensionResponse handles null gracefully', () {
      expect(parseExtensionResponse(null), isNull);
    });

    test('parseExtensionResponse handles invalid JSON gracefully', () {
      expect(parseExtensionResponse('not json{'), isNull);
    });
  });
}
