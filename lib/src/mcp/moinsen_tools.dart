import 'dart:convert';

import 'package:logging/logging.dart' as logging;
import 'package:mcp_dart/mcp_dart.dart';
import 'package:moinsen_runapp/src/mcp/moinsen_connector.dart';

/// Registers all moinsen MCP tools on the given [server].
void registerMoinsenTools(McpServer server, MoinsenConnector connector) {
  final logger = logging.Logger('MoinsenTools');

  // -- Connection management --

  server
    ..registerTool(
      'connect',
      description:
          'Connects to a Flutter app via its VM service URI. '
          'Must be called before using any other tools. '
          'The URI is printed in the Flutter console when running in '
          'debug mode (e.g. ws://127.0.0.1:8181/ws).',
      annotations: const ToolAnnotations(title: 'Connect to App'),
      inputSchema: ToolInputSchema(
        properties: {
          'uri': JsonSchema.string(
            description: 'VM service URI (e.g., ws://127.0.0.1:8181/ws)',
          ),
        },
        required: ['uri'],
      ),
      callback: (args, extra) async {
        final uri = args['uri'] as String;
        logger.info('Connecting to $uri');
        try {
          await connector.connect(uri);
          return CallToolResult(
            content: [TextContent(text: 'Connected to app at $uri')],
          );
        } on Object catch (e) {
          return _error('Failed to connect: $e');
        }
      },
    )
    ..registerTool(
      'disconnect',
      description: 'Disconnects from the currently connected app.',
      annotations: const ToolAnnotations(title: 'Disconnect'),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        await connector.disconnect();
        return const CallToolResult(
          content: [TextContent(text: 'Disconnected')],
        );
      },
    )
    // -- Observation tools --
    ..registerTool(
      'get_errors',
      description:
          'Get deduplicated error report from the running app. '
          'Returns error types, counts, sources, and stack traces.',
      annotations: const ToolAnnotations(
        title: 'Get Errors',
        readOnlyHint: true,
        idempotentHint: true,
      ),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        try {
          final result = await connector.getErrors();
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'clear_errors',
      description: 'Clear all tracked errors and reset error state.',
      annotations: const ToolAnnotations(title: 'Clear Errors'),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        try {
          final result = await connector.clearErrors();
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'get_logs',
      description:
          'Get recent app-level log entries (from moinsenLog calls). '
          'Returns timestamp, level, source, and message.',
      annotations: const ToolAnnotations(
        title: 'Get Logs',
        readOnlyHint: true,
      ),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        try {
          final result = await connector.getLogs();
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'get_route',
      description:
          'Get current route and navigation history. '
          'Shows route names, actions (push/pop/replace), and timestamps.',
      annotations: const ToolAnnotations(
        title: 'Get Route',
        readOnlyHint: true,
        idempotentHint: true,
      ),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        try {
          final result = await connector.getRoute();
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'navigate',
      description: 'Push a named route or pop the current route.',
      annotations: const ToolAnnotations(title: 'Navigate'),
      inputSchema: ToolInputSchema(
        properties: {
          'route': JsonSchema.string(
            description: 'Named route to push (e.g. "/settings")',
          ),
          'pop': JsonSchema.boolean(
            description: 'Set to true to pop the current route',
          ),
        },
      ),
      callback: (args, extra) async {
        try {
          final params = <String, String>{};
          if (args['route'] case final String route) {
            params['route'] = route;
          }
          if (args['pop'] == true) params['pop'] = 'true';
          final result = await connector.navigate(params);
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'get_device_info',
      description:
          'Get device and environment info: OS, screen dimensions, '
          'pixel ratio, locale, accessibility, text scale.',
      annotations: const ToolAnnotations(
        title: 'Get Device Info',
        readOnlyHint: true,
        idempotentHint: true,
      ),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        try {
          final result = await connector.getDeviceInfo();
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'get_lifecycle',
      description:
          'Get app lifecycle state (resumed, inactive, paused, etc.) '
          'and transition history with timestamps.',
      annotations: const ToolAnnotations(
        title: 'Get Lifecycle',
        readOnlyHint: true,
        idempotentHint: true,
      ),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        try {
          final result = await connector.getLifecycle();
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'get_network',
      description:
          'Get HTTP traffic records: method, URL, status code, '
          'duration, request/response sizes. Sensitive headers redacted.',
      annotations: const ToolAnnotations(
        title: 'Get Network',
        readOnlyHint: true,
      ),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        try {
          final result = await connector.getNetwork();
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'get_state',
      description:
          'Get registered app state snapshots (from moinsenExposeState). '
          'Optionally pass a key to query a specific state.',
      annotations: const ToolAnnotations(
        title: 'Get State',
        readOnlyHint: true,
      ),
      inputSchema: ToolInputSchema(
        properties: {
          'key': JsonSchema.string(
            description: 'Optional: specific state key to query',
          ),
        },
      ),
      callback: (args, extra) async {
        try {
          final key = args['key'] as String?;
          final result = await connector.getState(key);
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'take_screenshot',
      description:
          'Capture the current screen as a PNG image. '
          'Returns base64-encoded image data.',
      annotations: const ToolAnnotations(
        title: 'Take Screenshot',
        readOnlyHint: true,
      ),
      inputSchema: ToolInputSchema(
        properties: {
          'scale': JsonSchema.number(
            description:
                'Optional pixel ratio (e.g. 1.0 for 1x). '
                'Default uses device pixel ratio.',
          ),
        },
      ),
      callback: (args, extra) async {
        try {
          final scale = args['scale'] as num?;
          final result = await connector.screenshot(
            scale: scale?.toDouble(),
          );

          final base64 = result['screenshot'] as String?;
          if (base64 != null) {
            return CallToolResult(
              content: [
                ImageContent(data: base64, mimeType: 'image/png'),
              ],
            );
          }
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'get_prompt',
      description:
          'Get an LLM-optimized bug report in markdown format. '
          'Includes errors, logs, route, and platform info.',
      annotations: const ToolAnnotations(
        title: 'Get Bug Report',
        readOnlyHint: true,
      ),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        try {
          final result = await connector.getPrompt();
          final prompt = result['prompt'] as String?;
          return CallToolResult(
            content: [TextContent(text: prompt ?? jsonEncode(result))],
          );
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    // -- Interaction tools --
    ..registerTool(
      'get_interactive_elements',
      description:
          'List all interactive elements currently on screen. '
          'Returns type, key, text, bounds, and visibility for each. '
          'Requires enableInteraction: true in the app config.',
      annotations: const ToolAnnotations(
        title: 'Get Interactive Elements',
        readOnlyHint: true,
        idempotentHint: true,
      ),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        try {
          final result = await connector.getInteractiveElements();
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'tap',
      description:
          'Tap an element by key, text, widget type, or coordinates. '
          'Precedence: coordinates > key > text > type. '
          'Requires enableInteraction: true in the app config.',
      annotations: const ToolAnnotations(title: 'Tap Element'),
      inputSchema: ToolInputSchema(
        properties: {
          'key': JsonSchema.string(
            description: 'ValueKey<String> of the widget to tap',
          ),
          'text': JsonSchema.string(
            description: 'Visible text content of the widget',
          ),
          'type': JsonSchema.string(
            description: 'Runtime type name (e.g. "ElevatedButton")',
          ),
          'x': JsonSchema.number(
            description: 'X coordinate for direct tap',
          ),
          'y': JsonSchema.number(
            description: 'Y coordinate for direct tap',
          ),
        },
      ),
      callback: (args, extra) async {
        try {
          final params = _extractMatcherParams(args);
          final result = await connector.tap(params);
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'enter_text',
      description:
          'Enter text into a text field matched by key, text, or type. '
          'Requires enableInteraction: true in the app config.',
      annotations: const ToolAnnotations(title: 'Enter Text'),
      inputSchema: ToolInputSchema(
        properties: {
          'input': JsonSchema.string(
            description: 'Text to enter into the field',
          ),
          'key': JsonSchema.string(
            description: 'ValueKey<String> of the text field',
          ),
          'text': JsonSchema.string(
            description: 'Current text content to match',
          ),
          'type': JsonSchema.string(
            description: 'Widget type name (e.g. "TextField")',
          ),
        },
        required: ['input'],
      ),
      callback: (args, extra) async {
        try {
          final params = _extractMatcherParams(args);
          params['input'] = args['input'] as String;
          final result = await connector.enterText(params);
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'scroll_to',
      description:
          'Scroll until a target element becomes visible and hittable. '
          'Match by key or text. Max 50 scroll attempts. '
          'Requires enableInteraction: true in the app config.',
      annotations: const ToolAnnotations(title: 'Scroll To'),
      inputSchema: ToolInputSchema(
        properties: {
          'key': JsonSchema.string(
            description: 'ValueKey<String> of the target widget',
          ),
          'text': JsonSchema.string(
            description: 'Text content of the target widget',
          ),
        },
      ),
      callback: (args, extra) async {
        try {
          final params = _extractMatcherParams(args);
          final result = await connector.scrollTo(params);
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    // -- Dev tools --
    ..registerTool(
      'hot_reload',
      description:
          'Hot reload the Flutter app. Reloads Dart code without '
          'losing state.',
      annotations: const ToolAnnotations(title: 'Hot Reload'),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        try {
          final result = await connector.hotReload();
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'hot_restart',
      description: 'Hot restart the Flutter app. Full restart, loses state.',
      annotations: const ToolAnnotations(title: 'Hot Restart'),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        try {
          final result = await connector.hotRestart();
          return _json(result);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    // -- Composite tools --
    ..registerTool(
      'observe',
      description:
          'The "tell me everything" tool. Returns full app context '
          '(errors, logs, route, device, lifecycle, network, state) '
          'plus a screenshot and interactive elements in one call. '
          'Use this to quickly understand the current app state.',
      annotations: const ToolAnnotations(
        title: 'Observe App',
        readOnlyHint: true,
      ),
      inputSchema: const ToolInputSchema(properties: {}),
      callback: (args, extra) async {
        try {
          final context = await connector.getContext();
          final screenshot = await connector.screenshot();
          final elements = await _safeCall(
            connector.getInteractiveElements,
          );

          final combined = Map<String, dynamic>.from(context);
          if (elements != null) {
            combined['interactiveElements'] = elements;
          }

          final content = <Content>[
            TextContent(
              text: const JsonEncoder.withIndent('  ').convert(combined),
            ),
          ];

          final base64 = screenshot['screenshot'] as String?;
          if (base64 != null) {
            content.add(
              ImageContent(data: base64, mimeType: 'image/png'),
            );
          }

          return CallToolResult(content: content);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    )
    ..registerTool(
      'interact_and_verify',
      description:
          'Execute an interaction (tap, enter_text, or scroll_to), '
          'wait briefly, then take a screenshot to verify the result. '
          'Returns the action result and a verification screenshot. '
          'Requires enableInteraction: true in the app config.',
      annotations: const ToolAnnotations(
        title: 'Interact and Verify',
      ),
      inputSchema: ToolInputSchema(
        properties: {
          'action': JsonSchema.string(
            description:
                'Action to perform: "tap", "enter_text", or "scroll_to"',
          ),
          'key': JsonSchema.string(
            description: 'ValueKey<String> of the target widget',
          ),
          'text': JsonSchema.string(
            description: 'Text content to match',
          ),
          'type': JsonSchema.string(
            description: 'Widget type name',
          ),
          'x': JsonSchema.number(
            description: 'X coordinate (for tap)',
          ),
          'y': JsonSchema.number(
            description: 'Y coordinate (for tap)',
          ),
          'input': JsonSchema.string(
            description: 'Text to enter (for enter_text action)',
          ),
        },
        required: ['action'],
      ),
      callback: (args, extra) async {
        try {
          final action = args['action'] as String;
          final params = _extractMatcherParams(args);

          // Execute the action.
          Map<String, dynamic> actionResult;
          switch (action) {
            case 'tap':
              actionResult = await connector.tap(params);
            case 'enter_text':
              params['input'] = args['input'] as String? ?? '';
              actionResult = await connector.enterText(params);
            case 'scroll_to':
              actionResult = await connector.scrollTo(params);
            default:
              return _error(
                'Unknown action "$action". '
                'Use "tap", "enter_text", or "scroll_to".',
              );
          }

          // Wait for UI to settle.
          await Future<void>.delayed(
            const Duration(milliseconds: 300),
          );

          // Take verification screenshot.
          final screenshot = await connector.screenshot();

          final content = <Content>[
            TextContent(
              text: jsonEncode({
                'action': action,
                'result': actionResult,
              }),
            ),
          ];

          final base64 = screenshot['screenshot'] as String?;
          if (base64 != null) {
            content.add(
              ImageContent(data: base64, mimeType: 'image/png'),
            );
          }

          return CallToolResult(content: content);
        } on Object catch (e) {
          return _error('$e');
        }
      },
    );
}

/// Extract matcher params from tool args, converting to strings.
Map<String, String> _extractMatcherParams(Map<String, dynamic> args) {
  final params = <String, String>{};
  if (args['x'] case final num x) params['x'] = x.toString();
  if (args['y'] case final num y) params['y'] = y.toString();
  if (args['key'] case final String key) params['key'] = key;
  if (args['text'] case final String text) params['text'] = text;
  if (args['type'] case final String type) params['type'] = type;
  return params;
}

CallToolResult _json(Map<String, dynamic> data) {
  return CallToolResult(
    content: [
      TextContent(
        text: const JsonEncoder.withIndent('  ').convert(data),
      ),
    ],
  );
}

CallToolResult _error(String message) {
  return CallToolResult(
    isError: true,
    content: [TextContent(text: message)],
  );
}

/// Call a connector method, returning null on failure instead of throwing.
Future<Map<String, dynamic>?> _safeCall(
  Future<Map<String, dynamic>> Function() fn,
) async {
  try {
    return await fn();
  } on Object {
    return null;
  }
}
