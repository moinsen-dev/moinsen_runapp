import 'dart:io' show exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moinsen_runapp/src/error_entry.dart';
import 'package:moinsen_runapp/src/error_observer.dart';
import 'package:moinsen_runapp/src/prompt_generator.dart';

/// Developer-facing error screen shown in debug mode.
///
/// Dark theme, monospace font, scrollable error list with
/// expandable stack traces and action buttons.
class DebugErrorScreen extends StatelessWidget {
  const DebugErrorScreen({
    required this.observer,
    required this.onDismiss,
    required this.onClear,
    super.key,
  });

  final ErrorObserver observer;
  final VoidCallback onDismiss;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: const Color(0xE6181818),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Divider(color: Color(0xFF333333), height: 1),
              Expanded(child: _buildErrorList()),
              const Divider(color: Color(0xFF333333), height: 1),
              _buildActionBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ListenableBuilder(
      listenable: observer,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand line.
              const Row(
                children: [
                  Text(
                    'moinsen',
                    style: TextStyle(
                      color: Color(0xFF4A9AF5),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    ' error catcher',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 13,
                      fontFamily: 'monospace',
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Error count line.
              Row(
                children: [
                  const Icon(
                    Icons.bug_report,
                    color: Color(0xFFFF6B6B),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${observer.uniqueErrorCount} Unique Error'
                    '${observer.uniqueErrorCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (observer.totalErrorCount >
                      observer.uniqueErrorCount)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x33FF6B6B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${observer.totalErrorCount} total',
                        style: const TextStyle(
                          color: Color(0xFFFF9999),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorList() {
    return ListenableBuilder(
      listenable: observer,
      builder: (context, _) {
        final errors = observer.errors;
        if (errors.isEmpty) {
          return const Center(
            child: Text(
              'No errors',
              style: TextStyle(
                color: Color(0xFF888888),
                fontFamily: 'monospace',
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: errors.length,
          itemBuilder: (_, index) => _DebugErrorTile(
            entry: errors[index],
          ),
        );
      },
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          _ActionButton(
            icon: Icons.copy,
            label: 'Copy All',
            onTap: () => _copyAll(context),
          ),
          _ActionButton(
            icon: Icons.visibility,
            label: 'Dismiss',
            onTap: onDismiss,
          ),
          _ActionButton(
            icon: Icons.refresh,
            label: 'Clear & Retry',
            onTap: onClear,
          ),
          _ActionButton(
            icon: Icons.power_settings_new,
            label: 'Kill App',
            onTap: () => exit(0),
            destructive: true,
          ),
        ],
      ),
    );
  }

  Future<void> _copyAll(BuildContext context) async {
    final report = generateBugReport(
      errors: observer.errors,
      platform: defaultTargetPlatform.name,
    );
    await Clipboard.setData(ClipboardData(text: report));
  }
}

class _DebugErrorTile extends StatefulWidget {
  const _DebugErrorTile({required this.entry});

  final ErrorEntry entry;

  @override
  State<_DebugErrorTile> createState() => _DebugErrorTileState();
}

class _DebugErrorTileState extends State<_DebugErrorTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF333333),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _sourceColor(entry.source),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.source,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (entry.count > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${entry.count}×',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                const Spacer(),
                Icon(
                  _expanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: const Color(0xFF666666),
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.error.runtimeType}',
              style: const TextStyle(
                color: Color(0xFFFF9999),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              entry.label,
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              maxLines: _expanded ? null : 2,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              const Divider(
                color: Color(0xFF333333),
                height: 1,
              ),
              const SizedBox(height: 8),
              Text(
                entry.stackTrace.toString(),
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _sourceColor(String source) {
    return switch (source) {
      'flutter' => const Color(0xFF4A9AF5),
      'platform' => const Color(0xFFE6A23C),
      'zone' => const Color(0xFF67C23A),
      'init' => const Color(0xFFF56C6C),
      _ => const Color(0xFF909399),
    };
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  static const _accentBlue = Color(0xFF4A9AF5);
  static const _accentRed = Color(0xFFFF6B6B);

  Color get _accent =>
      widget.destructive ? _accentRed : _accentBlue;

  Color get _foreground =>
      widget.destructive ? _accentRed : const Color(0xFFCCCCCC);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: _pressed
              ? const Color(0xFF3A3A3A)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _pressed ? _accent : const Color(0xFF444444),
          ),
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: _pressed ? 0.7 : 1.0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: _foreground, size: 16),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: _foreground,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
