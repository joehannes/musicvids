import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ListPopupEntry<T> {
  const ListPopupEntry({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
}

Future<T?> showListPopup<T>({
  required BuildContext context,
  required String title,
  required List<ListPopupEntry<T>> entries,
  T? selectedValue,
  String? helperText,
}) {
  return showDialog<T>(
    context: context,
    builder: (_) => _ListPopupDialog<T>(
      title: title,
      entries: entries,
      selectedValue: selectedValue,
      helperText: helperText,
    ),
  );
}

class _ListPopupDialog<T> extends StatefulWidget {
  const _ListPopupDialog({
    required this.title,
    required this.entries,
    this.selectedValue,
    this.helperText,
  });

  final String title;
  final List<ListPopupEntry<T>> entries;
  final T? selectedValue;
  final String? helperText;

  @override
  State<_ListPopupDialog<T>> createState() => _ListPopupDialogState<T>();
}

class _ListPopupDialogState<T> extends State<_ListPopupDialog<T>> {
  late int _highlightedIndex;

  @override
  void initState() {
    super.initState();
    if (widget.entries.isEmpty) {
      _highlightedIndex = 0;
      return;
    }
    if (widget.selectedValue == null) {
      _highlightedIndex = 0;
      return;
    }
    final index = widget.entries.indexWhere((entry) => entry.value == widget.selectedValue);
    _highlightedIndex = index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
        SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),
        SingleActivator(LogicalKeyboardKey.keyJ): DirectionalFocusIntent(TraversalDirection.down),
        SingleActivator(LogicalKeyboardKey.keyK): DirectionalFocusIntent(TraversalDirection.up),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
            onInvoke: (intent) {
              if (widget.entries.isEmpty) return null;
              setState(() {
                if (intent.direction == TraversalDirection.down) {
                  _highlightedIndex = (_highlightedIndex + 1) % widget.entries.length;
                } else if (intent.direction == TraversalDirection.up) {
                  _highlightedIndex = (_highlightedIndex - 1) % widget.entries.length;
                  if (_highlightedIndex < 0) {
                    _highlightedIndex = widget.entries.length - 1;
                  }
                }
              });
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (widget.entries.isEmpty) return null;
              Navigator.pop(context, widget.entries[_highlightedIndex].value);
              return null;
            },
          ),
        },
        child: AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.helperText != null) ...[
                  Text(widget.helperText!, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                ],
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.entries.length,
                    itemBuilder: (_, index) {
                      final entry = widget.entries[index];
                      final selected = index == _highlightedIndex;
                      return Card(
                        color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
                        child: ListTile(
                          dense: true,
                          selected: selected,
                          leading: entry.leading,
                          trailing: entry.trailing,
                          title: Text(entry.label),
                          subtitle: entry.subtitle == null ? null : Text(entry.subtitle!),
                          onTap: () => Navigator.pop(context, entry.value),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: widget.entries.isEmpty ? null : () => Navigator.pop(context, widget.entries[_highlightedIndex].value),
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }
}
