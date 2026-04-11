import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../state/app_state.dart';

class TouchShortcutsGuide extends StatefulWidget {
  final AppState state;
  final Function(String) onActionExecuted;
  final Function() onClose;

  const TouchShortcutsGuide({
    super.key,
    required this.state,
    required this.onActionExecuted,
    required this.onClose,
  });

  @override
  State<TouchShortcutsGuide> createState() => _TouchShortcutsGuideState();
}

class _TouchShortcutsGuideState extends State<TouchShortcutsGuide> {
  String? _selectedCategory;
  final Map<String, IconData> _categoryIcons = {
    'Navigation': FontAwesomeIcons.compass,
    'Project': FontAwesomeIcons.file,
    'Channel': FontAwesomeIcons.tv,
    'Lyrics': FontAwesomeIcons.music,
    'Storyboard': FontAwesomeIcons.film,
    'Character': FontAwesomeIcons.person,
    'Generation': FontAwesomeIcons.clapperboard,
    'Settings': FontAwesomeIcons.gear,
    'Custom': FontAwesomeIcons.star,
  };

  final Map<String, IconData> _actionIcons = {
    'new': FontAwesomeIcons.plus,
    'save': FontAwesomeIcons.floppyDisk,
    'open': FontAwesomeIcons.folderOpen,
    'delete': FontAwesomeIcons.trash,
    'refresh': FontAwesomeIcons.rotateRight,
    'sync': FontAwesomeIcons.arrowsRotate,
    'export': FontAwesomeIcons.download,
    'import': FontAwesomeIcons.upload,
    'add': FontAwesomeIcons.plus,
    'remove': FontAwesomeIcons.minus,
    'create': FontAwesomeIcons.plus,
    'update': FontAwesomeIcons.pencil,
    'run': FontAwesomeIcons.play,
    'next': FontAwesomeIcons.chevronRight,
    'prev': FontAwesomeIcons.chevronLeft,
    'previous': FontAwesomeIcons.chevronLeft,
  };

  IconData _extractActionIcon(String action) {
    final lower = action.toLowerCase();
    for (final entry in _actionIcons.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return FontAwesomeIcons.circle;
  }

  List<Map<String, String>> _getCategoryActions(String category) {
    final actions = <Map<String, String>>[];
    for (final entry in widget.state.shortcutBindings.entries) {
      final meta = widget.state.shortcutMeta[entry.key];
      if ((meta?['category'] ?? 'Action') == category) {
        actions.add({
          'title': meta?['label'] ?? entry.key,
          'sequence': entry.value.trim(),
          'key': entry.key,
        });
      }
    }
    return actions;
  }

  void _executeAction(String sequence, String actionKey) {
    widget.onActionExecuted(actionKey);
    setState(() => _selectedCategory = null);
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>{};
    for (final meta in widget.state.shortcutMeta.values) {
      categories.add(meta['category'] ?? 'Action');
    }

    return GestureDetector(
      onTap: widget.onClose,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 64, right: 8),
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping on the menu itself
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header button (back or main)
                  if (_selectedCategory != null)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedCategory = null),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withOpacity(0.3),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  FontAwesomeIcons.chevronLeft,
                                  size: 14,
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _selectedCategory ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.5),
                        ),
                        child: Text(
                          'Shortcuts',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Menu items
                  if (_selectedCategory == null)
                    // Show categories
                    ...categories.toList().map((category) {
                      final icon = _categoryIcons[category] ??
                          FontAwesomeIcons.circle;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedCategory = category),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withOpacity(0.3),
                                    ),
                                    child: Icon(
                                      icon,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ),
                                  Icon(
                                    FontAwesomeIcons.chevronRight,
                                    size: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList()
                  else
                    // Show category actions
                    ..._getCategoryActions(_selectedCategory!)
                        .map((action) {
                      final icon =
                          _extractActionIcon(action['title'] ?? '');
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _executeAction(
                              action['sequence'] ?? '',
                              action['key'] ?? '',
                            ),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                          .withOpacity(0.3),
                                    ),
                                    child: Icon(
                                      icon,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      action['title'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
