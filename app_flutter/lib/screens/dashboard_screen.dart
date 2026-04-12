import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../widgets/list_popup.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/touch_shortcuts_guide.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _CanvasScreen {
  const _CanvasScreen({required this.id, required this.label, required this.icon, required this.offset});
  final String id;
  final String label;
  final IconData icon;
  final Offset offset;
}

class _CanvasNote {
  _CanvasNote({required this.position, required this.text});
  Offset position;
  String text;
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _newProjectController = TextEditingController();
  final FocusNode _keyboardFocus = FocusNode();
  final Map<String, Offset> _screenPanOffsets = {};
  final Map<String, List<_CanvasNote>> _screenNotes = {};

  final List<_CanvasScreen> _screens = const [
    _CanvasScreen(id: 'dashboard', label: 'Dashboard', icon: Icons.dashboard, offset: Offset.zero),
    _CanvasScreen(id: 'projects', label: 'Projects', icon: Icons.folder, offset: Offset.zero),
    _CanvasScreen(id: 'lyrics', label: 'Lyrics', icon: Icons.library_music, offset: Offset.zero),
    _CanvasScreen(id: 'channels', label: 'Channels', icon: Icons.people, offset: Offset.zero),
    _CanvasScreen(id: 'storyboard', label: 'Storyboard', icon: Icons.view_timeline, offset: Offset.zero),
    _CanvasScreen(id: 'characters', label: 'Characters', icon: Icons.person, offset: Offset.zero),
    _CanvasScreen(id: 'generation', label: 'Generation', icon: Icons.movie, offset: Offset.zero),
    _CanvasScreen(id: 'preview', label: 'Preview', icon: Icons.preview, offset: Offset.zero),
    _CanvasScreen(id: 'upload', label: 'Upload', icon: Icons.upload, offset: Offset.zero),
  ];

  String _activeScreenId = 'dashboard';
  bool _mnemonicMode = false;
  String _mnemonicSequence = '';
  Timer? _mnemonicTimer;
  bool _mnemonicFailed = false;
  bool _globalKeyHandlerRegistered = false;
  bool _youtubeGridView = true;
  Map<int, bool> _expandedChannels = {};
  final TextEditingController _youtubeSearchController = TextEditingController();
  final FocusNode _youtubeSearchFocus = FocusNode();
  int _selectedChannelIndex = 0;
  final TextEditingController _projectsSearchController = TextEditingController();
  final FocusNode _projectsSearchFocus = FocusNode();
  int _selectedProjectIndex = 0;
  Timer? _autosaveTimer;
  static const Duration _autosaveDebounceDuration = Duration(milliseconds: 500);
  static const int _defaultYouTubeAccessTokenLifetimeSeconds = 3600;
  static const double _tokenRefreshThresholdRatio = 0.10;
  bool _showTouchGuide = false;
  Offset? _lastSecondaryPointerPosition;
  String? _oauthHydratedProjectName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().bootstrap();
      _keyboardFocus.requestFocus();
      if (!_globalKeyHandlerRegistered) {
        HardwareKeyboard.instance.addHandler(_globalKeyHandler);
        _globalKeyHandlerRegistered = true;
      }
    });
  }

  @override
  void dispose() {
    _mnemonicTimer?.cancel();
    _autosaveTimer?.cancel();
    _newProjectController.dispose();
    _keyboardFocus.dispose();
    _youtubeSearchController.dispose();
    _youtubeSearchFocus.dispose();
    _projectsSearchController.dispose();
    _projectsSearchFocus.dispose();
    if (_globalKeyHandlerRegistered) {
      HardwareKeyboard.instance.removeHandler(_globalKeyHandler);
      _globalKeyHandlerRegistered = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Focus(
          autofocus: true,
          focusNode: _keyboardFocus,
          child: Stack(
            children: [
              Positioned.fill(
                top: 56, // Leave space for taskbar
                child: _buildCanvas(state),
              ),
              // Fixed top taskbar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 56,
                child: _buildFixedTaskbar(state),
              ),
              if (_mnemonicMode) _buildMnemonicGuide(state),
              if (_showTouchGuide)
                TouchShortcutsGuide(
                  state: state,
                  onActionExecuted: (actionKey) async {
                    await _executeMnemonicAction(state, actionKey);
                    setState(() => _showTouchGuide = false);
                    // Re-enable after short delay for UX
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (mounted) {
                      setState(() => _showTouchGuide = true);
                    }
                  },
                  onClose: () => setState(() => _showTouchGuide = false),
                ),
              if (state.loading)
                Positioned(
                  top: 56,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _globalKeyHandler(KeyEvent event) {
    if (!mounted) {
      return false;
    }
    final state = context.read<AppState>();
    return _onKeyEvent(state, event) == KeyEventResult.handled;
  }

  Widget _buildFixedTaskbar(AppState state) {
    final currentScreen = _screens.firstWhere((s) => s.id == _activeScreenId);
    final activeProjectHint = state.selectedProject;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Screen selector dropdown (left side)
          Tooltip(
            message: 'Select View/Screen',
            child: PopupMenuButton<String>(
              tooltip: '',
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(currentScreen.icon, size: 18),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
              onSelected: (screenId) => _setActiveScreen(screenId),
              itemBuilder: (context) => _screens
                  .map((screen) => PopupMenuItem(
                        value: screen.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(screen.icon, size: 18),
                            const SizedBox(width: 12),
                            Text(screen.label),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            activeProjectHint != null && _activeScreenId == 'projects'
                ? '${currentScreen.label} • $activeProjectHint'
                : currentScreen.label,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const Spacer(),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildContextualActions(state),
          ),
          
          // Touch guide toggle on far right
          Tooltip(
            message: 'Toggle Shortcuts Guide',
            child: IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.lightbulb),
              onPressed: () => setState(() => _showTouchGuide = !_showTouchGuide),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextualActions(AppState state) {
    switch (_activeScreenId) {
      case 'dashboard':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton('Create Project', Icons.add_box, () {
              var hasProject = state.activeProject != null;
              if (hasProject) return;
              _showQuickCreateProjectDialog(state);
            }),
            _iconButton('Save Project', Icons.save, () => state.saveActiveProject()),
            _iconButton('Refresh', Icons.refresh, () => state.bootstrap()),
            _iconButton('Help', Icons.help_outline, () => _startMnemonicMode()),
          ],
        );
      case 'projects':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton('New Project', Icons.add_box, () => _showQuickCreateProjectDialog(state)),
            _iconButton('Load Selected', Icons.folder_open, () async {
              final project = _projectsSearchController.text.trim().isEmpty
                  ? state.projects.firstOrNull
                  : state.projects.where((p) => _fuzzyMatch(p, _projectsSearchController.text)).firstOrNull;
              if (project != null) {
                await state.loadProject(project);
                _showSnack('Loaded: $project');
              }
            }),
            _iconButton('Refresh', Icons.refresh, () => state.refreshProjects()),
            _iconButton('Export Full Project', Icons.download, () => _exportFullProject(state)),
            _iconButton('Import Full Project', Icons.upload, () => _importFullProject(state)),
            _iconButton('Save', Icons.save, () => state.saveActiveProject()),
          ],
        );
      case 'lyrics':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton('Select Language', Icons.translate, () => _showLanguagePicker(state)),
            _iconButton('Add Language', Icons.language, () => _showAddLanguageDialog(state)),
            _iconButton('Remove Current Language', Icons.language_outlined, () => _removeCurrentLanguage(state)),
            _iconButton('Add Section', Icons.add, () => _addLyricSection(state)),
            _iconButton('Delete Last', Icons.delete, () => _deleteLastLyricSection(state)),
            _iconButton('Next Chapter', Icons.skip_next, () => state.nextEpisode()),
            _iconButton('Previous Chapter', Icons.skip_previous, () => state.previousEpisode()),
            _iconButton('Export Lyrics', Icons.download, () => _exportLyrics(state)),
            _iconButton('Import Lyrics', Icons.upload, () => _importLyrics(state)),
            _iconButton('Save', Icons.save, () => state.saveActiveProject()),
          ],
        );
      case 'channels':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton('Setup OAuth', Icons.login, () => _startOAuthFlow(state)),
            _iconButton('Add Manual', Icons.add, () => _showAddChannelDialog(state)),
            _iconButton('Generate Pattern', Icons.functions, () => _showBatchChannelDialog(state)),
            _iconButton('Test Connection', Icons.check_circle, () => _testOAuthConnection(state)),
            _iconButton('Sync All', Icons.sync, () => _syncAllChannels(state)),
            _iconButton('Export Channels', Icons.download, () => _exportChannels(state)),
            _iconButton('Import Channels', Icons.upload, () => _importChannels(state)),
            _iconButton('Select All', Icons.select_all, () => _selectAllChannels(state)),
            _iconButton('Deselect All', Icons.deselect, () => _deselectAllChannels(state)),
            _iconButton('Open YouTube', Icons.open_in_new, () => _openYouTubeChannelCreation(state)),
            _iconButton(
              _youtubeGridView ? 'Switch to list view' : 'Switch to grid view',
              _youtubeGridView ? Icons.view_list : Icons.grid_view,
              () => setState(() => _youtubeGridView = !_youtubeGridView),
            ),
          ],
        );
      case 'storyboard':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton('Add Scene', Icons.add, () => _addScene(state)),
            _iconButton('Delete Last', Icons.delete, () => _deleteLastScene(state)),
            _iconButton('Clear All', Icons.delete_sweep, () => _clearAllScenes(state)),
            _iconButton('Export Storyboard', Icons.download, () => _exportStoryboard(state)),
            _iconButton('Import Storyboard', Icons.upload, () => _importStoryboard(state)),
            _iconButton('Save', Icons.save, () => state.saveActiveProject()),
          ],
        );
      case 'characters':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton('Add Character', Icons.person_add, () => _addCharacter(state)),
            _iconButton('Delete Last', Icons.person_remove, () => _deleteLastCharacter(state)),
            _iconButton('Clear All', Icons.delete_sweep, () => _clearAllCharacters(state)),
            _iconButton('Export Characters', Icons.download, () => _exportCharacters(state)),
            _iconButton('Import Characters', Icons.upload, () => _importCharacters(state)),
            _iconButton('Save', Icons.save, () => state.saveActiveProject()),
          ],
        );
      case 'generation':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton('Run Workflow', Icons.play_circle, () => state.runWorkflow()),
            _iconButton('Next Episode', Icons.skip_next, () => state.nextEpisode()),
            _iconButton('Previous Episode', Icons.skip_previous, () => state.previousEpisode()),
            if (state.lastWorkflowReport != null)
              _iconButton('Report Available', Icons.assessment, () {
                _showSnack('Workflow Report Generated - see below');
              }),
          ],
        );
      case 'preview':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton('Refresh Preview', Icons.refresh, () => setState(() {})),
            _iconButton('Export Preview', Icons.download, () => _showSnack('Export preview feature coming soon')),
            _iconButton('Share', Icons.share, () => _showSnack('Share feature coming soon')),
          ],
        );
      case 'upload':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton('Upload Video', Icons.cloud_upload, () => _showSnack('Upload workflow coming soon')),
            _iconButton('Schedule Upload', Icons.schedule, () => _showSnack('Schedule feature coming soon')),
            _iconButton('Batch Upload', Icons.upload_file, () => _showSnack('Batch upload coming soon')),
            _iconButton('Check Status', Icons.info, () => _showSnack('Status check coming soon')),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _iconButton(String tooltip, IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          icon: Icon(icon),
          onPressed: onPressed,
        ),
      ),
    );
  }

  void _deleteLastScene(AppState state) {
    final project = state.activeProject;
    if (project == null) return;
    final storyboard = (project['storyboard'] as Map<String, dynamic>? ?? {'globalMood': '', 'scenes': []});
    final scenes = (storyboard['scenes'] as List?)?.cast<Map>() ?? [];
    if (scenes.isNotEmpty) {
      scenes.removeLast();
      storyboard['scenes'] = scenes;
      project['storyboard'] = storyboard;
      state.touch();
      _scheduleAutosave(state);
      _showSnack('Scene deleted.');
    }
  }

  void _clearAllScenes(AppState state) {
    final project = state.activeProject;
    if (project == null) return;
    final storyboard = (project['storyboard'] as Map<String, dynamic>? ?? {'globalMood': '', 'scenes': []});
    storyboard['scenes'] = [];
    project['storyboard'] = storyboard;
    state.touch();
    _scheduleAutosave(state);
    _showSnack('All scenes cleared.');
  }

  void _deleteLastCharacter(AppState state) {
    final project = state.activeProject;
    if (project == null) return;
    final characters = (project['characters'] as List?)?.cast<Map>() ?? [];
    if (characters.isNotEmpty) {
      characters.removeLast();
      project['characters'] = characters;
      state.touch();
      _scheduleAutosave(state);
      _showSnack('Character deleted.');
    }
  }

  void _clearAllCharacters(AppState state) {
    final project = state.activeProject;
    if (project == null) return;
    project['characters'] = [];
    state.touch();
    _scheduleAutosave(state);
    _showSnack('All characters cleared.');
  }

  KeyEventResult _onKeyEvent(AppState state, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final keyLabel = key.keyLabel.toLowerCase();
    final textFieldFocused = _isTextFieldFocused();

    // Allow ESC to work even when text field is focused (to unfocus/exit)
    if (key == LogicalKeyboardKey.escape) {
      if (textFieldFocused) {
        // Unfocus the text field
        _keyboardFocus.requestFocus();
        return KeyEventResult.handled;
      }
      if (_mnemonicMode) {
        _cancelMnemonic();
        return KeyEventResult.handled;
      }
    }

    // Disable ALL mnemonic shortcuts when a text field is focused
    if (textFieldFocused) {
      return KeyEventResult.ignored;
    }

    if (!_mnemonicMode && key == LogicalKeyboardKey.space) {
      _startMnemonicMode();
      return KeyEventResult.handled;
    }

    if (!_mnemonicMode && ['h', 'j', 'k', 'l'].contains(keyLabel)) {
      _scrollByDirection(keyLabel);
      return KeyEventResult.handled;
    }

    if (_mnemonicMode) {
      if (key == LogicalKeyboardKey.backspace) {
        if (_mnemonicSequence.isNotEmpty) {
          final parts = _mnemonicSequence.split(' ');
          parts.removeLast();
          _mnemonicSequence = parts.join(' ');
          _mnemonicFailed = false;
          setState(() {});
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
      if (RegExp(r'^[a-z]$').hasMatch(keyLabel)) {
        _mnemonicSequence = _mnemonicSequence.isEmpty ? keyLabel : '$_mnemonicSequence $keyLabel';
        _mnemonicFailed = false;
        if (_matchesKnownShortcut(_mnemonicSequence, state)) {
          unawaited(_resolveMnemonicSequence(state));
          return KeyEventResult.handled;
        }
        setState(() {});
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Widget _buildCanvas(AppState state) {
    final viewport = MediaQuery.sizeOf(context);
    final pan = _screenPanOffsets[_activeScreenId] ?? Offset.zero;
    final notes = _screenNotes[_activeScreenId] ?? <_CanvasNote>[];

    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kSecondaryMouseButton) {
          _lastSecondaryPointerPosition = event.position;
        }
      },
      onPointerMove: (event) {
        if (event.buttons != kSecondaryMouseButton || _lastSecondaryPointerPosition == null) {
          return;
        }
        final delta = event.position - _lastSecondaryPointerPosition!;
        _lastSecondaryPointerPosition = event.position;
        final current = _screenPanOffsets[_activeScreenId] ?? Offset.zero;
        setState(() {
          _screenPanOffsets[_activeScreenId] = current + delta;
        });
      },
      onPointerUp: (_) => _lastSecondaryPointerPosition = null,
      onPointerCancel: (_) => _lastSecondaryPointerPosition = null,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
            ),
            Transform.translate(
              offset: pan,
              child: _pageForScreen(_activeScreenId, state),
            ),
            ...notes.map((note) => Positioned(
                  left: viewport.width / 2 + note.position.dx + pan.dx,
                  top: viewport.height / 2 + note.position.dy + pan.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        note.position += details.delta;
                      });
                    },
                    child: SizedBox(
                      width: 260,
                      child: Card(
                        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                        child: ListTile(
                          title: const Text('Canvas Note'),
                          subtitle: Text(note.text),
                          leading: const Icon(Icons.drag_indicator),
                        ),
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _getCategoryFirstLetter(String category, AppState state) {
    // Find first shortcut that belongs to this category and get its first letter
    for (final entry in state.shortcutBindings.entries) {
      final meta = state.shortcutMeta[entry.key];
      if (meta?['category'] == category) {
        final sequence = entry.value.trim();
        if (sequence.isNotEmpty) {
          return sequence.split(' ').first.toUpperCase();
        }
      }
    }
    // Fallback: return first letter of category
    return category.isNotEmpty ? category[0].toUpperCase() : '?';
  }

  Widget _buildMnemonicGuide(AppState state) {
    final available = <Map<String, String>>[];
    final nextLetters = <String>{};
    final categoriesMap = <String, int>{};

    for (final entry in state.shortcutBindings.entries) {
      final sequence = entry.value.trim();
      if (sequence.isEmpty) continue;
      final tokens = sequence.split(RegExp(r'\s+'));
      final meta = state.shortcutMeta[entry.key] ?? {'category': 'Action', 'label': entry.key, 'description': ''};

      if (_mnemonicSequence.isEmpty || sequence.startsWith(_mnemonicSequence)) {
        available.add({
          'title': '${meta['category']} → ${meta['label']}',
          'description': meta['description'] ?? 'Available shortcut action',
          'sequence': sequence,
          'category': meta['category'] ?? 'Action',
        });
        if (_mnemonicSequence.isEmpty) {
          categoriesMap[meta['category'] ?? 'Action'] = (categoriesMap[meta['category'] ?? 'Action'] ?? 0) + 1;
        }
      }

      if (_mnemonicSequence.isEmpty) {
        nextLetters.add(tokens.first);
      } else if (sequence.startsWith(_mnemonicSequence)) {
        final currentTokens = _mnemonicSequence.split(' ');
        if (tokens.length > currentTokens.length) {
          nextLetters.add(tokens[currentTokens.length]);
        }
      }
    }

    for (final custom in state.customShortcuts) {
      final sequence = (custom['sequence'] ?? '').trim();
      if (sequence.isEmpty) continue;
      final tokens = sequence.split(RegExp(r'\s+'));

      if (_mnemonicSequence.isEmpty || sequence.startsWith(_mnemonicSequence)) {
        available.add({
          'title': 'Custom → ${custom['label'] ?? 'Action'}',
          'description': 'User defined shortcut',
          'sequence': sequence,
          'category': 'Custom',
        });
        if (_mnemonicSequence.isEmpty) {
          categoriesMap['Custom'] = (categoriesMap['Custom'] ?? 0) + 1;
        }
      }

      if (_mnemonicSequence.isEmpty) {
        nextLetters.add(tokens.first);
      } else if (sequence.startsWith(_mnemonicSequence)) {
        final currentTokens = _mnemonicSequence.split(' ');
        if (tokens.length > currentTokens.length) {
          nextLetters.add(tokens[currentTokens.length]);
        }
      }
    }

    available.sort((a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));

    // Show categories on initial state, shortcuts otherwise
    final isInitialState = _mnemonicSequence.isEmpty;

    final screenSize = MediaQuery.sizeOf(context);
    final containerWidth = ((screenSize.width * 0.75).clamp(600.0, double.infinity) as double);
    final containerHeight = ((screenSize.height * 0.75).clamp(300.0, double.infinity) as double);

    return Align(
      alignment: Alignment.center,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: 1,
        child: Container(
          width: containerWidth,
          constraints: BoxConstraints(maxHeight: containerHeight),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _mnemonicFailed ? Colors.red.withOpacity(0.6) : Colors.black.withOpacity(0.6),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isInitialState ? 'Mnemonic Categories' : 'Mnemonic Guide',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                isInitialState
                    ? 'Press the letter shown to see shortcuts in that category'
                    : (_mnemonicSequence.isEmpty ? 'Type a sequence (example: S O)' : 'Sequence: $_mnemonicSequence')
                        .replaceAll('Type a sequence', 'Continue typing or press Backspace to go back'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              if (!isInitialState)
                Wrap(
                  spacing: 8,
                  children: nextLetters
                      .map((n) => Chip(
                            label: Text(n.toUpperCase()),
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.25),
                          ))
                      .toList(),
                ),
              if (!isInitialState) const SizedBox(height: 10),
              MouseRegion(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    scrollbars: true,
                  ),
                  child: SizedBox(
                    height: isInitialState ? (containerHeight * 0.5).clamp(180, 300) : (containerHeight * 0.6).clamp(300, double.infinity),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: isInitialState
                          ? GridView.count(
                              crossAxisCount: 4,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 8,
                              childAspectRatio: 2.8,
                              children: categoriesMap.entries
                                  .map((e) {
                                    final firstLetter = _getCategoryFirstLetter(e.key, state);
                                    return Card(
                                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                                      child: InkWell(
                                        onTap: () {
                                          // Simulate typing the first letter
                                          setState(() {
                                            _mnemonicSequence = firstLetter.toLowerCase();
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                  border: Border.all(
                                                    color: Theme.of(context).colorScheme.primary,
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    firstLetter,
                                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                          color: Theme.of(context).colorScheme.primary,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      e.key,
                                                      textAlign: TextAlign.left,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                            fontWeight: FontWeight.w700,
                                                            fontSize: 10,
                                                          ),
                                                    ),
                                                    Text(
                                                      '${e.value} item${e.value != 1 ? 's' : ''}',
                                                      textAlign: TextAlign.left,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            color: Colors.grey[500],
                                                            fontSize: 8,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(),
                            )
                          : ListView(
                              children: available
                                  .map((e) => ListTile(
                                        dense: true,
                                        visualDensity: VisualDensity.compact,
                                        title: Text(e['title'] ?? ''),
                                        subtitle: Text(e['description'] ?? ''),
                                        trailing: Text((e['sequence'] ?? '').toUpperCase()),
                                      ))
                                  .toList(),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Press ESC to close • Press Backspace to go back • Press a letter to continue',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesKnownShortcut(String sequence, AppState state) {
    final normalized = sequence.trim();
    if (state.shortcutBindings.values.any((value) => value.trim() == normalized)) {
      return true;
    }
    return state.customShortcuts.any((entry) => (entry['sequence'] ?? '').trim() == normalized);
  }

  Widget _pageForScreen(String id, AppState state) {
    if (state.error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.red.withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(state.error!),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: state.bootstrap,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry backend connection'),
          ),
        ],
      );
    }

    switch (id) {
      case 'dashboard':
        return _dashboardPage(state);
      case 'projects':
        return _projectsPage(state);
      case 'lyrics':
        return _lyricsPage(state);
      case 'channels':
        return _channelsPage(state);
      case 'storyboard':
        return _storyboardPage(state);
      case 'characters':
        return _charactersPage(state);
      case 'generation':
        return _generationPage(state);
      case 'preview':
        return _previewPage(state);
      case 'upload':
        return _uploadPage(state);
      default:
        return const SizedBox.shrink();
    }
  }

  void _startMnemonicMode() {
    _mnemonicTimer?.cancel();
    setState(() {
      _mnemonicMode = true;
      _mnemonicSequence = '';
      _mnemonicFailed = false;
    });
  }

  void _restartMnemonicTimer(AppState state) {
    // Timer no longer used - guide persists until shortcut triggered or ESC pressed
    _mnemonicTimer?.cancel();
  }

  Future<void> _executeMnemonicAction(AppState state, String actionKey) async {
    await _runAction(actionKey, state);
  }

  Future<void> _resolveMnemonicSequence(AppState state) async {
    final action = state.shortcutBindings.entries
        .firstWhere((entry) => entry.value.trim() == _mnemonicSequence.trim(), orElse: () => const MapEntry('', ''))
        .key;

    if (action.isEmpty) {
      final custom = state.customShortcuts.firstWhere(
        (entry) => (entry['sequence'] ?? '').trim() == _mnemonicSequence.trim(),
        orElse: () => {},
      );
      if (custom.isNotEmpty) {
        _showSnack('Custom shortcut: ${custom['label']}');
        _cancelMnemonic();
        return;
      }
      setState(() {
        _mnemonicFailed = true;
      });
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) {
        _cancelMnemonic();
      }
      return;
    }

    // Dismiss guide first, then run action
    _cancelMnemonic();
    if (mounted) {
      await _runAction(action, state);
    }
  }

  void _cancelMnemonic() {
    _mnemonicTimer?.cancel();
    setState(() {
      _mnemonicMode = false;
      _mnemonicSequence = '';
      _mnemonicFailed = false;
    });
  }

  Future<void> _runAction(String action, AppState state) async {
    // Map action prefixes to their primary screen
    final actionToScreen = <String, String>{
      'lyrics.': 'lyrics',
      'channel.': 'channels',
      'storyboard.': 'storyboard',
      'character.': 'characters',
      'generation.': 'generation',
    };

    // Check if this action requires navigation to a specific screen
    String? targetScreen;
    for (final entry in actionToScreen.entries) {
      if (action.startsWith(entry.key)) {
        targetScreen = entry.value;
        break;
      }
    }

    // Navigate to the screen first if needed
    if (targetScreen != null && _activeScreenId != targetScreen) {
      _setActiveScreen(targetScreen);
      // Small delay to ensure screen is rendered before executing action
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    switch (action) {
      case 'navigate.left':
        _moveScreen(-1, 0);
        break;
      case 'navigate.right':
        _moveScreen(1, 0);
        break;
      case 'navigate.up':
        _panWithinScreen(0, 1);
        break;
      case 'navigate.down':
        _panWithinScreen(0, -1);
        break;
      case 'canvas.note.new':
        _addCanvasNote();
        break;
      case 'canvas.center':
        _resetCanvasPan();
        break;
      case 'navigate.dashboard':
        _setActiveScreen('dashboard');
        break;
      case 'navigate.projects':
        _setActiveScreen('projects');
        break;
      case 'navigate.lyrics':
        _setActiveScreen('lyrics');
        break;
      case 'navigate.channels':
        _setActiveScreen('channels');
        break;
      case 'navigate.storyboard':
        _setActiveScreen('storyboard');
        break;
      case 'navigate.characters':
        _setActiveScreen('characters');
        break;
      case 'navigate.generation':
        _setActiveScreen('generation');
        break;
      case 'navigate.preview':
        _setActiveScreen('preview');
        break;
      case 'navigate.upload':
        _setActiveScreen('upload');
        break;
      case 'navigate.screen_picker':
        await _openScreenPicker();
        break;
      case 'project.new':
        await _showQuickCreateProjectDialog(state);
        break;
      case 'project.open':
        if (state.projects.isEmpty) {
          _showSnack('No projects available yet.');
          break;
        }
        await state.loadProject(state.projects.first);
        if (state.activeProject == null) {
          _showSnack('Project load failed. Check backend status.');
        } else {
          _showSnack('Opened first project in list.');
        }
        break;
      case 'project.save':
        await state.saveActiveProject();
        _showSnack('Project saved.');
        break;
      case 'project.refresh':
        await state.bootstrap();
        _showSnack('Refreshed project and backend state.');
        break;
      case 'channel.new':
        _addChannel(state);
        break;
      case 'channel.update':
      case 'channel.sync':
        _showSnack('Channel synchronization placeholder triggered.');
        break;
      case 'lyrics.new':
        await _addLyricSection(state);
        break;
      case 'lyrics.delete':
        _deleteLastLyricSection(state);
        break;
      case 'lyrics.chapter':
        state.nextEpisode();
        _showSnack('Moved to next chapter/generation context.');
        break;
      case 'storyboard.scene.new':
        _addScene(state);
        break;
      case 'character.new':
        _addCharacter(state);
        break;
      case 'generation.run':
        await state.runWorkflow();
        break;
      case 'generation.next':
        state.nextEpisode();
        break;
      case 'generation.prev':
        state.previousEpisode();
        break;
      case 'settings.open':
        await _openSettings(state);
        break;
      case 'search.projects':
        _activeScreenId = 'dashboard';
        setState(() {});
        _projectsSearchFocus.requestFocus();
        break;
      case 'search.channels':
        _activeScreenId = 'dashboard';
        setState(() {});
        _youtubeSearchFocus.requestFocus();
        break;
      case 'search.lyrics':
        _activeScreenId = 'dashboard';
        setState(() {});
        // Lyrics search focus will be added when implementing lyrics search
        break;
      case 'search.storyboard':
        _activeScreenId = 'dashboard';
        setState(() {});
        // Storyboard search focus will be added when implementing storyboard search
        break;
      default:
        _showSnack('No handler for action "$action" yet.');
    }
  }

  void _scrollByDirection(String direction) {
    final viewport = MediaQuery.sizeOf(context);
    final deltaX = viewport.width / 5;
    final deltaY = viewport.height / 5;
    if (direction == 'h') {
      _panWithinScreen(deltaX, 0);
    } else if (direction == 'l') {
      _panWithinScreen(-deltaX, 0);
    } else if (direction == 'k') {
      _panWithinScreen(0, deltaY);
    } else if (direction == 'j') {
      _panWithinScreen(0, -deltaY);
    }
  }

  void _moveScreen(int dx, int dy) {
    if (dy != 0) {
      return;
    }
    final currentIndex = _screens.indexWhere((s) => s.id == _activeScreenId);
    if (currentIndex < 0) return;
    final nextIndex = (currentIndex + dx) % _screens.length;
    setState(() {
      _activeScreenId = _screens[nextIndex < 0 ? _screens.length + nextIndex : nextIndex].id;
    });
  }

  void _setActiveScreen(String screenId) {
    if (_activeScreenId == screenId) return;
    setState(() {
      _activeScreenId = screenId;
    });
  }

  Future<void> _openScreenPicker() async {
    final selected = await showListPopup<String>(
      context: context,
      title: 'Select screen/view',
      helperText: 'Navigate with j/k or ↑/↓ then Enter.',
      selectedValue: _activeScreenId,
      entries: _screens
          .map(
            (screen) => ListPopupEntry<String>(
              value: screen.id,
              label: screen.label,
              leading: Icon(screen.icon),
              subtitle: 'Open ${screen.label} view',
            ),
          )
          .toList(),
    );
    if (selected != null) {
      _setActiveScreen(selected);
    }
  }

  void _panWithinScreen(double dx, double dy) {
    final current = _screenPanOffsets[_activeScreenId] ?? Offset.zero;
    setState(() {
      _screenPanOffsets[_activeScreenId] = Offset(current.dx + dx, current.dy + dy);
    });
  }

  void _resetCanvasPan() {
    setState(() {
      _screenPanOffsets[_activeScreenId] = Offset.zero;
    });
  }

  void _addCanvasNote() {
    final notes = _screenNotes.putIfAbsent(_activeScreenId, () => <_CanvasNote>[]);
    setState(() {
      notes.add(_CanvasNote(position: const Offset(0, 0), text: 'New component placeholder'));
    });
  }

  bool _isTextFieldFocused() {
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null) {
      return false;
    }
    
    // Check if the focused node is associated with any text input widget
    // by checking the context's widget hierarchy
    BuildContext? context = focused.context;
    if (context == null) {
      return false;
    }
    
    // Use visitAncestorElements to check for EditableText in the widget tree
    bool foundEditableText = false;
    context.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        foundEditableText = true;
        return false;
      }
      return true;
    });
    
    return foundEditableText;
  }

  Future<void> _openSettings(AppState state) async {
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SettingsDialog(initial: state.settings),
    );
    if (updated != null) {
      await state.saveSettings(updated);
      _showSnack('Settings and shortcut bindings saved.');
    }
  }

  void _showLanguagePicker(AppState state) async {
    final project = state.activeProject;
    if (project == null) return;
    final lyrics = _ensureLyricsStructure(project);
    final languages = (lyrics['languages'] as List).cast<String>();
    final currentLanguage = lyrics['current_language']?.toString() ?? languages.first;
    final selected = await showListPopup<String>(
      context: context,
      title: 'Select lyrics language',
      helperText: 'Switch editing language.',
      selectedValue: currentLanguage,
      entries: languages
          .map((lang) => ListPopupEntry<String>(
                value: lang,
                label: lang.toUpperCase(),
                subtitle: lang == currentLanguage ? 'Current' : 'Switch to this language',
              ))
          .toList(),
    );
    if (selected != null) {
      lyrics['current_language'] = selected;
      state.touch();
    }
  }

  void _showAddLanguageDialog(AppState state) async {
    final project = state.activeProject;
    if (project == null) return;
    final lyrics = _ensureLyricsStructure(project);
    final languages = (lyrics['languages'] as List).cast<String>();
    final blocks = (lyrics['blocks'] as List).cast<Map<String, dynamic>>();
    final input = TextEditingController();
    final newLang = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add language'),
        content: TextField(
          controller: input,
          decoration: const InputDecoration(
            labelText: 'Language code (en, es, fr...)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, input.text.trim().toLowerCase()), child: const Text('Add')),
        ],
      ),
    );
    if (newLang == null || newLang.isEmpty || languages.contains(newLang)) return;
    languages.add(newLang);
    for (final block in blocks) {
      final texts = (block['texts'] as Map).cast<String, dynamic>();
      texts[newLang] = '';
    }
    lyrics['current_language'] = newLang;
    state.touch();
  }

  void _removeCurrentLanguage(AppState state) {
    final project = state.activeProject;
    if (project == null) return;
    final lyrics = _ensureLyricsStructure(project);
    final languages = (lyrics['languages'] as List).cast<String>();
    if (languages.length <= 1) {
      _showSnack('At least one language must remain.');
      return;
    }
    final currentLanguage = lyrics['current_language']?.toString() ?? languages.first;
    final blocks = (lyrics['blocks'] as List).cast<Map<String, dynamic>>();
    languages.remove(currentLanguage);
    for (final block in blocks) {
      final texts = (block['texts'] as Map).cast<String, dynamic>();
      texts.remove(currentLanguage);
    }
    lyrics['current_language'] = languages.first;
    state.touch();
  }

  Future<void> _showQuickCreateProjectDialog(AppState state) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create project'),
        content: TextField(controller: _newProjectController, decoration: const InputDecoration(labelText: 'Project name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, _newProjectController.text), child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await state.createProject(name.trim());
      _newProjectController.clear();
      _showSnack('Created project $name.');
    }
  }

  void _addChannel(AppState state) {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }
    final channels = (project['channels'] as List?)?.cast<Map>() ?? [];
    final lyrics = _ensureLyricsStructure(project);
    final defaultLang = ((lyrics['languages'] as List?)?.isNotEmpty ?? false) 
        ? (lyrics['languages'] as List).first.toString() 
        : 'en';
    
    channels.add({
      'channel_id': 'channel_${channels.length + 1}',
      'language': defaultLang,
      'title': 'New Channel',
      'handle': '',
      'description': '',
      'keywords': '',
      'brand_category': '',
      'overall_style': 'cinematic',
      'channel_style': '',
      'vibe': 'experimental',
      'visual_style': 'stylized',
      'enabled': true,
      'yt_oauth_status': 'not_configured',
    });
    project['channels'] = channels;
    state.touch();
    _scheduleAutosave(state);
    _showSnack('Channel added.');
  }

  void _selectAllChannels(AppState state) {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }
    final channels = (project['channels'] as List?)?.cast<Map>() ?? [];
    int count = 0;
    for (final ch in channels) {
      if (ch['enabled'] != true) {
        ch['enabled'] = true;
        count++;
      }
    }
    if (count > 0) {
      state.touch();
      _scheduleAutosave(state);
      _showSnack('✓ Enabled $count channels.');
    }
  }

  void _deselectAllChannels(AppState state) {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }
    final channels = (project['channels'] as List?)?.cast<Map>() ?? [];
    int count = 0;
    for (final ch in channels) {
      if (ch['enabled'] != false) {
        ch['enabled'] = false;
        count++;
      }
    }
    if (count > 0) {
      state.touch();
      _scheduleAutosave(state);
      _showSnack('✓ Disabled $count channels.');
    }
  }

  Future<void> _addLyricSection(AppState state) async {
    var project = state.activeProject;
    if (project == null && state.projects.isNotEmpty) {
      await state.loadProject(state.projects.first);
      project = state.activeProject;
    }
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }
    final lyrics = _ensureLyricsStructure(project);
    final languages = (lyrics['languages'] as List).cast<String>();
    final blocks = (lyrics['blocks'] as List).cast<Map<String, dynamic>>();
    final textByLanguage = <String, dynamic>{
      for (final lang in languages) lang: '',
    };
    blocks.add({'muted': false, 'texts': textByLanguage});
    state.touch();
    _showSnack('Lyric section added.');
  }

  void _deleteLastLyricSection(AppState state) {
    final project = state.activeProject;
    if (project == null) return;
    final lyrics = _ensureLyricsStructure(project);
    final blocks = (lyrics['blocks'] as List).cast<Map<String, dynamic>>();
    if (blocks.isNotEmpty) {
      blocks.removeLast();
      state.touch();
      _showSnack('Removed last lyric section.');
    }
  }

  Map<String, dynamic> _ensureLyricsStructure(Map<String, dynamic> project) {
    final raw = (project['lyrics'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final alreadyStructured = raw['languages'] is List && raw['blocks'] is List;
    if (alreadyStructured) {
      final languages = ((raw['languages'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList());
      if (languages.isEmpty) {
        languages.add('en');
      }
      raw['languages'] = languages;
      raw['current_language'] = languages.contains(raw['current_language']) ? raw['current_language'] : languages.first;
      raw['tone_notes'] = raw['tone_notes']?.toString() ?? '';
      raw['blocks'] = ((raw['blocks'] as List).map((entry) {
        final block = (entry as Map).cast<String, dynamic>();
        final texts = (block['texts'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        for (final language in languages) {
          texts[language] = texts[language]?.toString() ?? '';
        }
        return <String, dynamic>{
          'muted': block['muted'] == true,
          'texts': texts,
        };
      }).toList());
      project['lyrics'] = raw;
      return raw;
    }

    final migratedLanguages = <String>[];
    final blocks = <Map<String, dynamic>>[];
    var toneNotes = '';
    for (final entry in raw.entries) {
      final language = entry.key;
      final value = (entry.value as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      migratedLanguages.add(language);
      final sections = (value['sections'] as List?)?.map((section) => section.toString()).toList() ?? <String>[''];
      for (var i = 0; i < sections.length; i++) {
        if (i >= blocks.length) {
          blocks.add({'muted': false, 'texts': <String, dynamic>{}});
        }
        final texts = (blocks[i]['texts'] as Map).cast<String, dynamic>();
        texts[language] = sections[i];
      }
      if (toneNotes.isEmpty) {
        toneNotes = value['tone_notes']?.toString() ?? '';
      }
    }
    if (migratedLanguages.isEmpty) {
      migratedLanguages.add('en');
      blocks.add({
        'muted': false,
        'texts': {'en': ''},
      });
    }
    for (final block in blocks) {
      final texts = (block['texts'] as Map).cast<String, dynamic>();
      for (final language in migratedLanguages) {
        texts[language] = texts[language]?.toString() ?? '';
      }
    }

    final structured = <String, dynamic>{
      'languages': migratedLanguages,
      'current_language': migratedLanguages.first,
      'blocks': blocks,
      'tone_notes': toneNotes,
    };
    project['lyrics'] = structured;
    return structured;
  }

  void _addScene(AppState state) {
    final project = state.activeProject;
    if (project == null) return;
    final storyboard = (project['storyboard'] as Map<String, dynamic>? ?? {'globalMood': '', 'scenes': []});
    final scenes = (storyboard['scenes'] as List?)?.cast<Map>() ?? [];
    scenes.add({'text': '', 'imagery': '', 'type': 'single', 'manualStart': null, 'manualEnd': null});
    storyboard['scenes'] = scenes;
    project['storyboard'] = storyboard;
    state.touch();
    _showSnack('Scene added.');
  }

  void _addCharacter(AppState state) {
    final project = state.activeProject;
    if (project == null) return;
    final characters = (project['characters'] as List?)?.cast<Map>() ?? [];
    characters.add({'name': 'New Character', 'description': '', 'variations': ['default']});
    project['characters'] = characters;
    state.touch();
    _showSnack('Character added.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _dashboardPage(AppState state) {
    final project = state.activeProject;
    if (project == null) return const Center(child: Text('Load a project first.'));
    
    final channels = (project['channels'] as List?) ?? [];
    final scenes = (project['storyboard']?['scenes'] as List?) ?? [];
    final characters = (project['characters'] as List?) ?? [];
    
    // Get or initialize generation moods
    final generationMoods = (project['generation_moods'] as Map?)?.cast<String, dynamic>() ?? {
      'music_mood': 'cinematic, inspiring',
      'image_mood': 'photorealistic, cinematic',
      'video_mood': 'smooth transitions, dynamic',
    };
    project['generation_moods'] = generationMoods;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metricCard('Backend', state.backendOnline ? 'Online' : 'Offline'),
            _metricCard('Projects', '${state.projects.length}'),
            _metricCard('Channels', '${channels.length}'),
            _metricCard('Scenes', '${scenes.length}'),
            _metricCard('Characters', '${characters.length}'),
            _metricCard('Episode', '${state.selectedEpisodeIndex + 1}'),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            title: Text('Active project: ${state.selectedProject ?? 'None'}'),
            subtitle: const Text('Navigate through canvas via mnemonic mode (Space → keys) or h/j/k/l scroll'),
          ),
        ),
        const SizedBox(height: 16),
        Text('Generation Moods', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'These moods apply to all channels and generation steps for this project.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: generationMoods['music_mood']?.toString() ?? '',
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '🎵 Music Mood (Suno)',
                    border: OutlineInputBorder(),
                    helperText: 'Applied to all song generation (combine with channel styles)',
                  ),
                  onChanged: (v) {
                    generationMoods['music_mood'] = v;
                    state.touch();
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: generationMoods['image_mood']?.toString() ?? '',
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '🖼️ Image Mood (Midjourney)',
                    border: OutlineInputBorder(),
                    helperText: 'Applied to all image generation',
                  ),
                  onChanged: (v) {
                    generationMoods['image_mood'] = v;
                    state.touch();
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: generationMoods['video_mood']?.toString() ?? '',
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '🎬 Video Mood (FFmpeg)',
                    border: OutlineInputBorder(),
                    helperText: 'Applied to video transitions and effects',
                  ),
                  onChanged: (v) {
                    generationMoods['video_mood'] = v;
                    state.touch();
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (state.lastWorkflowReport != null) ...[
          Text('Last workflow report', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(const JsonEncoder.withIndent('  ').convert(state.lastWorkflowReport)),
        ],
      ],
    );
  }

  Widget _projectsPage(AppState state) {
    // Filter projects based on search query
    final searchQuery = _projectsSearchController.text.trim().toLowerCase();
    final filteredProjects = state.projects.where((name) {
      if (searchQuery.isEmpty) return true;
      return _fuzzyMatch(name, searchQuery);
    }).toList();

    // Clamp selected index to filtered list
    if (filteredProjects.isEmpty) {
      _selectedProjectIndex = 0;
    } else if (_selectedProjectIndex >= filteredProjects.length) {
      _selectedProjectIndex = filteredProjects.length - 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.projects.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _projectsSearchController,
                focusNode: _projectsSearchFocus,
                decoration: InputDecoration(
                  labelText: 'Search projects (fuzzy)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _projectsSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _projectsSearchController.clear();
                            setState(() => _selectedProjectIndex = 0);
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() => _selectedProjectIndex = 0);
                },
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: filteredProjects.length,
            itemBuilder: (_, displayIndex) {
              final name = filteredProjects[displayIndex];
              final isSelected = displayIndex == _selectedProjectIndex;
              final isActiveProject = name == state.selectedProject;
              return Focus(
                onKey: (node, event) {
                  if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
                    setState(() {
                      if (_selectedProjectIndex < filteredProjects.length - 1) {
                        _selectedProjectIndex++;
                      }
                    });
                    return KeyEventResult.handled;
                  } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
                    setState(() {
                      if (_selectedProjectIndex > 0) {
                        _selectedProjectIndex--;
                      }
                    });
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                autofocus: isSelected,
                child: Container(
                  decoration: isSelected
                      ? BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                  child: Card(
                    color: isActiveProject ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.45) : null,
                    child: ListTile(
                      leading: Icon(isActiveProject ? Icons.task_alt : Icons.folder_open),
                      title: Text(name),
                      subtitle: Text(isActiveProject ? 'Active project' : 'Click to load'),
                      trailing: OutlinedButton(
                        onPressed: () async {
                          await state.loadProject(name);
                          if (!mounted) return;
                          setState(() {
                            _selectedProjectIndex = displayIndex;
                          });
                          _showSnack('Loaded project: $name');
                        },
                        child: const Text('Load'),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _lyricsPage(AppState state) {
    final project = state.activeProject;
    if (project == null) return const Center(child: Text('Load a project first.'));
    final lyrics = _ensureLyricsStructure(project);
    final languages = (lyrics['languages'] as List).cast<String>();
    final currentLanguage = (lyrics['current_language']?.toString().isNotEmpty ?? false)
        ? lyrics['current_language'].toString()
        : languages.first;
    lyrics['current_language'] = currentLanguage;
    final blocks = (lyrics['blocks'] as List).cast<Map<String, dynamic>>();
    final toneNotes = lyrics['tone_notes']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current language: ${currentLanguage.toUpperCase()} • ${languages.length} configured'),
        const SizedBox(height: 8),
        ...blocks.asMap().entries.map((entry) {
          final index = entry.key;
          final block = entry.value;
          final texts = (block['texts'] as Map).cast<String, dynamic>();
          final muted = block['muted'] == true;
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Lyrics block ${index + 1}', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Tooltip(
                        message: muted ? 'Block muted' : 'Block active',
                        child: Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: !muted,
                            onChanged: (value) {
                              block['muted'] = !value;
                              state.touch();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          final lyricsBlocks = (lyrics['blocks'] as List);
                          if (index < lyricsBlocks.length) {
                            lyricsBlocks.removeAt(index);
                            state.touch();
                          }
                        },
                        tooltip: 'Delete this block',
                        icon: const Icon(Icons.delete_outline),
                        iconSize: 20,
                      ),
                    ],
                  ),
                  TextFormField(
                    key: ValueKey('lyrics-$index-$currentLanguage'),
                    initialValue: texts[currentLanguage]?.toString() ?? '',
                    maxLines: 7,
                    minLines: 7,
                    decoration: InputDecoration(
                      labelText: '${currentLanguage.toUpperCase()} lyrics',
                      border: const OutlineInputBorder(),
                      filled: muted,
                    ),
                    onChanged: (value) {
                      texts[currentLanguage] = value;
                    },
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextFormField(
              initialValue: toneNotes,
              minLines: 5,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Tone/style notes',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => lyrics['tone_notes'] = value,
            ),
          ),
        ),
      ],
    );
  }

  Widget _channelsPage(AppState state) {
    final project = state.activeProject;
    if (project == null) return const Center(child: Text('Load a project first.'));
    _ensureChannelOAuthHydration(state);
    final channels = (project['channels'] as List?)?.cast<Map>() ?? [];
    final lyrics = _ensureLyricsStructure(project);
    final availableLangs = (lyrics['languages'] as List?)?.cast<String>() ?? ['en'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Control space for Suno generation
        _buildSunoControlSpace(state, project, availableLangs),
        const SizedBox(height: 20),
        
        // Channels management header
        Row(
          children: [
            Text('YouTube Channels', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 12),
        
        if (channels.isNotEmpty && !_youtubeGridView)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _youtubeSearchController,
                focusNode: _youtubeSearchFocus,
                decoration: InputDecoration(
                  labelText: 'Search channels (fuzzy)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _youtubeSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _youtubeSearchController.clear();
                            setState(() => _selectedChannelIndex = 0);
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() => _selectedChannelIndex = 0);
                },
              ),
            ),
          ),
        
        if (channels.isEmpty)
          Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('No channels configured yet. Use the top taskbar actions to add/sync channels.'),
              ),
            ),
        
        // Channels grid or list view
        if (_youtubeGridView)
          _buildYoutubeChannelsGrid(state, project, channels, availableLangs)
        else
          ..._buildYoutubeChannelsListFiltered(state, project, channels, availableLangs),
      ],
    );
  }

  Widget _buildYoutubeChannelsGrid(AppState state, Map<String, dynamic> project, List<dynamic> channels, List<String> availableLangs) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: channels.asMap().entries.map((e) {
        final index = e.key;
        final raw = e.value;
        final ch = raw.cast<String, dynamic>();
        final isEnabled = ch['enabled'] ?? true;
        final channelLang = ch['language']?.toString() ?? 'en';
        final isLanguageMuted = !availableLangs.contains(channelLang);
        final isExpanded = _expandedChannels[index] ?? false;

        return SizedBox(
          width: 320,
          child: Card(
            color: isLanguageMuted ? Theme.of(context).colorScheme.surface.withOpacity(0.5) : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: isExpanded
                  ? _buildYoutubeChannelExpandedContent(state, index, ch, isEnabled, channelLang, isLanguageMuted, availableLangs)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Compact grid view
                        Row(
                          children: [
                            Checkbox(
                              value: isEnabled,
                              onChanged: (v) {
                                if (v != null) {
                                  ch['enabled'] = v;
                                  state.touch();
                                }
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ch['title']?.toString() ?? 'Untitled',
                                    style: Theme.of(context).textTheme.titleSmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Language: ${channelLang.toUpperCase()}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => setState(() => _expandedChannels[index] = true),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _syncChannel(state, ch),
                                icon: const Icon(Icons.sync, size: 16),
                                label: const Text('Sync'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _deleteChannel(state, index),
                                icon: const Icon(Icons.delete, size: 16),
                                label: const Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _fuzzyMatch(String text, String pattern) {
    final textLower = text.toLowerCase();
    final patternLower = pattern.toLowerCase();
    
    int patternIndex = 0;
    for (int i = 0; i < textLower.length && patternIndex < patternLower.length; i++) {
      if (textLower[i] == patternLower[patternIndex]) {
        patternIndex++;
      }
    }
    return patternIndex == patternLower.length;
  }

  void _scheduleAutosave(AppState state) {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDebounceDuration, () async {
      if (state.activeProject != null && state.selectedProject != null) {
        try {
          await state.saveActiveProject();
          debugPrint('✓ Autosave OK: ${state.selectedProject}');
        } catch (e) {
          debugPrint('❌ Autosave FAILED for ${state.selectedProject}: $e');
          _showSnack('⚠️ Autosave failed: $e. Try clicking Save again.');
        }
      } else {
        debugPrint('⚠️ Autosave skipped: activeProject=${state.activeProject != null}, selectedProject=${state.selectedProject}');
      }
    });
  }

  List<Widget> _buildYoutubeChannelsListFiltered(AppState state, Map<String, dynamic> project, List<dynamic> channels, List<String> availableLangs) {
    final searchQuery = _youtubeSearchController.text.trim();
    
    // Filter channels based on search query
    final filteredIndices = <int>[];
    for (int i = 0; i < channels.length; i++) {
      final ch = (channels[i] as Map).cast<String, dynamic>();
      final channelId = ch['channel_id']?.toString() ?? '';
      
      if (searchQuery.isEmpty || _fuzzyMatch(channelId, searchQuery)) {
        filteredIndices.add(i);
      }
    }
    
    // Clamp selected index to filtered list
    if (filteredIndices.isEmpty) {
      _selectedChannelIndex = 0;
    } else if (_selectedChannelIndex >= filteredIndices.length) {
      _selectedChannelIndex = filteredIndices.length - 1;
    }
    
    return filteredIndices.asMap().entries.map((entry) {
      final displayIndex = entry.key;
      final originalIndex = entry.value;
      final isSelected = displayIndex == _selectedChannelIndex;
      
      final raw = channels[originalIndex];
      final ch = raw.cast<String, dynamic>();
      final isEnabled = ch['enabled'] ?? true;
      final channelLang = ch['language']?.toString() ?? 'en';
      final isLanguageMuted = !availableLangs.contains(channelLang);
      
      return Focus(
        onKey: (node, event) {
          if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
            setState(() {
              if (_selectedChannelIndex < filteredIndices.length - 1) {
                _selectedChannelIndex++;
              }
            });
            return KeyEventResult.handled;
          } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
            setState(() {
              if (_selectedChannelIndex > 0) {
                _selectedChannelIndex--;
              }
            });
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        autofocus: isSelected,
        child: Container(
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: _buildYoutubeChannelCard(state, originalIndex, ch, isEnabled, channelLang, isLanguageMuted, availableLangs),
        ),
      );
    }).toList();
  }

  List<Widget> _buildYoutubeChannelsList(AppState state, Map<String, dynamic> project, List<dynamic> channels, List<String> availableLangs) {
    return channels.asMap().entries.map((e) {
      final index = e.key;
      final raw = e.value;
      final ch = raw.cast<String, dynamic>();
      final isEnabled = ch['enabled'] ?? true;
      final channelLang = ch['language']?.toString() ?? 'en';
      final isLanguageMuted = !availableLangs.contains(channelLang);
      return _buildYoutubeChannelCard(state, index, ch, isEnabled, channelLang, isLanguageMuted, availableLangs);
    }).toList();
  }

  Widget _buildYoutubeChannelCard(AppState state, int index, Map<String, dynamic> ch, bool isEnabled, String channelLang, bool isLanguageMuted, List<String> availableLangs) {
    return Card(
      color: isLanguageMuted ? Theme.of(context).colorScheme.surface.withOpacity(0.5) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with enable toggle, channel ID, and action buttons
            Row(
              children: [
                Checkbox(
                  value: isEnabled,
                  onChanged: (v) {
                    if (v != null) {
                      ch['enabled'] = v;
                      state.touch();
                      _scheduleAutosave(state);
                    }
                  },
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: ch['channel_id']?.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Channel ID',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) {
                      ch['channel_id'] = v;
                      _scheduleAutosave(state);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Sync Channel',
                  child: IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.sync),
                    onPressed: () => _syncChannel(state, ch),
                  ),
                ),
                Tooltip(
                  message: 'Delete Channel',
                  child: IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteChannel(state, index),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Language field (code only) with available languages
            Opacity(
              opacity: isLanguageMuted ? 0.6 : 1.0,
              child: SizedBox(
                width: 120,
                child: Tooltip(
                  message: isLanguageMuted
                      ? 'This language is not used in the lyrics section. Add it to lyrics first.'
                      : 'Language used for content generation',
                  child: DropdownButtonFormField<String>(
                    value: channelLang,
                    items: availableLangs
                        .map((lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(lang.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: isLanguageMuted
                        ? null
                        : (v) {
                            if (v != null) {
                              ch['language'] = v;
                              state.touch();
                              _scheduleAutosave(state);
                            }
                          },
                    decoration: InputDecoration(
                      hintText: 'Language',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                      helperText: isLanguageMuted ? 'Not defined' : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Basic channel info
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: ch['title']?.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Channel Title',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      ch['title'] = v;
                      _scheduleAutosave(state);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: ch['handle']?.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Channel Handle (@username)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      ch['handle'] = v;
                      _scheduleAutosave(state);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Description
            TextFormField(
              initialValue: ch['description']?.toString(),
              decoration: const InputDecoration(
                labelText: 'Channel Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (v) {
                ch['description'] = v;
                _scheduleAutosave(state);
              },
            ),
            const SizedBox(height: 12),
            
            // Keywords and tags
            Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: ch['keywords']?.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Keywords (comma-separated)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            ch['keywords'] = v;
                            _scheduleAutosave(state);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: ch['brand_category']?.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Brand Category',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            ch['brand_category'] = v;
                            _scheduleAutosave(state);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Style settings
                  Text('Content Style', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: ch['overall_style']?.toString() ?? 'cinematic',
                          decoration: const InputDecoration(
                            labelText: 'Overall Style',
                            border: OutlineInputBorder(),
                            helperText: 'e.g., cinematic, documentary, artistic',
                          ),
                          onChanged: (v) {
                            ch['overall_style'] = v;
                            _scheduleAutosave(state);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: ch['channel_style']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Channel-Specific Style',
                            border: OutlineInputBorder(),
                            helperText: 'Channel branding style',
                          ),
                          onChanged: (v) {
                            ch['channel_style'] = v;
                            _scheduleAutosave(state);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Visual properties
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: ch['visual_style']?.toString() ?? 'stylized',
                          decoration: const InputDecoration(
                            labelText: 'Visual Style',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            ch['visual_style'] = v;
                            _scheduleAutosave(state);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: ch['vibe']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Vibe/Mood',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            ch['vibe'] = v;
                            _scheduleAutosave(state);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildChannelOAuthPanel(state, ch),
                  const SizedBox(height: 12),
                  _buildYoutubeMetadataPanel(ch),
                  
                  if (isLanguageMuted)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This channel language ($channelLang) is not defined in Lyrics. Add this language to the Lyrics section to enable editing.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
    }

  Widget _buildYoutubeChannelExpandedContent(AppState state, int index, Map<String, dynamic> ch, bool isEnabled, String channelLang, bool isLanguageMuted, List<String> availableLangs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Close button
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _expandedChannels[index] = false),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(height: 8),
        
        // Language field (code only)
        Opacity(
          opacity: isLanguageMuted ? 0.6 : 1.0,
          child: SizedBox(
            width: 120,
            child: Tooltip(
              message: isLanguageMuted
                  ? 'This language is not used in the lyrics section. Add it to lyrics first.'
                  : 'Language used for content generation',
              child: DropdownButtonFormField<String>(
                value: channelLang,
                items: availableLangs
                    .map((lang) => DropdownMenuItem(
                          value: lang,
                          child: Text(lang.toUpperCase()),
                        ))
                    .toList(),
                onChanged: isLanguageMuted
                    ? null
                    : (v) {
                        if (v != null) {
                          ch['language'] = v;
                          state.touch();
                          _scheduleAutosave(state);
                        }
                      },
                decoration: InputDecoration(
                  hintText: 'Language',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                  helperText: isLanguageMuted ? 'Not defined' : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Basic channel info
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: ch['title']?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Channel Title',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  ch['title'] = v;
                  _scheduleAutosave(state);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: ch['handle']?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Channel Handle (@username)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  ch['handle'] = v;
                  _scheduleAutosave(state);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Description
        TextFormField(
          initialValue: ch['description']?.toString(),
          decoration: const InputDecoration(
            labelText: 'Channel Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (v) {
            ch['description'] = v;
            _scheduleAutosave(state);
          },
        ),
        const SizedBox(height: 12),
        
        // Keywords and tags
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: ch['keywords']?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Keywords (comma-separated)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  ch['keywords'] = v;
                  _scheduleAutosave(state);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: ch['brand_category']?.toString(),
                decoration: const InputDecoration(
                  labelText: 'Brand Category',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  ch['brand_category'] = v;
                  _scheduleAutosave(state);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Style settings
        Text('Content Style', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: ch['overall_style']?.toString() ?? 'cinematic',
                decoration: const InputDecoration(
                  labelText: 'Overall Style',
                  border: OutlineInputBorder(),
                  helperText: 'e.g., cinematic, documentary, artistic',
                ),
                onChanged: (v) {
                  ch['overall_style'] = v;
                  _scheduleAutosave(state);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: ch['channel_style']?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'Channel-Specific Style',
                  border: OutlineInputBorder(),
                  helperText: 'Channel branding style',
                ),
                onChanged: (v) {
                  ch['channel_style'] = v;
                  _scheduleAutosave(state);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Visual properties
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: ch['visual_style']?.toString() ?? 'stylized',
                decoration: const InputDecoration(
                  labelText: 'Visual Style',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  ch['visual_style'] = v;
                  _scheduleAutosave(state);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: ch['vibe']?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'Vibe/Mood',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  ch['vibe'] = v;
                  _scheduleAutosave(state);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildChannelOAuthPanel(state, ch),
        const SizedBox(height: 12),
        _buildYoutubeMetadataPanel(ch),
        
        if (isLanguageMuted)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This channel language ($channelLang) is not defined in Lyrics. Add this language to the Lyrics section to enable editing.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChannelOAuthPanel(AppState state, Map<String, dynamic> ch) {
    final project = state.activeProject;
    final channelId = ch['channel_id']?.toString() ?? '';
    final tokenRecord = project == null || channelId.isEmpty ? null : _channelOAuthRecord(project, channelId);
    final status = tokenRecord?['status']?.toString() ?? 'not_configured';
    final expiresAt = tokenRecord?['access_token_expires_at']?.toString() ?? '';
    final refreshToken = tokenRecord?['refresh_token']?.toString() ?? '';
    final hasRefresh = refreshToken.isNotEmpty;
    final isExpiring = tokenRecord != null ? _isAccessTokenExpiring(tokenRecord) : false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Channel OAuth', style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => _showFetchRefreshTokenDialog(state, ch),
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: const Text('Fetch refresh token'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: hasRefresh ? () => _refreshChannelAccessToken(state, ch) : null,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh access token'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Status: $status${isExpiring ? ' (access token expiring)' : ''}'),
            Text('Refresh token saved: ${hasRefresh ? 'yes' : 'no'}'),
            if (expiresAt.isNotEmpty) Text('Access token expires at: $expiresAt'),
          ],
        ),
      ),
    );
  }

  Widget _buildYoutubeMetadataPanel(Map<String, dynamic> ch) {
    final syncedAt = ch['yt_synced_at']?.toString() ?? ch['_yt_synced_at']?.toString() ?? '';
    final channelId = ch['youtube_channel_id']?.toString().isNotEmpty == true
        ? ch['youtube_channel_id'].toString()
        : ch['channel_id']?.toString() ?? '';
    final subscribers = ch['yt_subscriber_count'] ?? ch['_yt_subscriber_count'] ?? 0;
    final videos = ch['yt_video_count'] ?? ch['_yt_video_count'] ?? 0;
    final views = ch['yt_view_count'] ?? ch['_yt_view_count'] ?? 0;
    final customUrl = ch['yt_custom_url']?.toString() ?? '';
    final country = ch['yt_country']?.toString() ?? '';
    final source = ch['yt_sync_source']?.toString() ?? '';
    final madeForKids = ch['yt_made_for_kids'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YouTube Sync Metadata', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText('Channel ID: $channelId'),
            if (customUrl.isNotEmpty) SelectableText('Handle URL: $customUrl'),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('Subscribers: $subscribers'),
                Text('Videos: $videos'),
                Text('Views: $views'),
                if (country.isNotEmpty) Text('Country: $country'),
                if (madeForKids != null) Text('Made for kids: $madeForKids'),
              ],
            ),
            if (source.isNotEmpty) Text('Sync source: $source'),
            if (syncedAt.isNotEmpty) Text('Last sync: $syncedAt'),
          ],
        ),
      ),
    );
  }

  void _syncChannel(AppState state, Map<String, dynamic> channel) async {
    final project = state.activeProject;
    if (project == null) return;
    final youtubeSettings = state.settings['youtube'] as Map?;
    final apiKey = youtubeSettings?['api_key']?.toString() ?? '';
    final channelId = channel['channel_id']?.toString() ?? '';
    if (channelId.isEmpty) {
      _showSnack('Channel ID is required for sync.');
      return;
    }
    final accessToken = await _ensureFreshChannelAccessToken(state, channel);
    final resolvedChannelId = channelId.startsWith('handle:')
        ? await _resolveYouTubeHandleToChannelId(channelId.replaceFirst('handle:', ''), apiKey: apiKey, oauthToken: accessToken)
        : channelId;
    if (resolvedChannelId == null || resolvedChannelId.isEmpty) {
      _showSnack('Could not resolve channel ID for sync.');
      return;
    }
    final query = {
      'part': 'snippet,statistics,contentDetails,brandingSettings,status,topicDetails,localizations',
      'id': resolvedChannelId,
      if (apiKey.isNotEmpty && (accessToken == null || accessToken.isEmpty)) 'key': apiKey,
    };
    final response = await http.get(
      Uri.https('www.googleapis.com', '/youtube/v3/channels', query),
      headers: accessToken != null && accessToken.isNotEmpty ? {'Authorization': 'Bearer $accessToken'} : {},
    );
    if (response.statusCode != 200) {
      _showSnack('Channel sync failed (HTTP ${response.statusCode}).');
      return;
    }
    _showSnack('✅ Synced ${channel['title'] ?? resolvedChannelId}.');
    _syncAllChannels(state);
  }

  void _exportChannels(AppState state) async {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }

    final channels = (project['channels'] as List?)?.cast<Map>() ?? [];
    if (channels.isEmpty) {
      _showSnack('No channels to export.');
      return;
    }

    // Build export data with only editable fields
    final exportData = {
      'version': '1.0',
      'export_date': DateTime.now().toIso8601String(),
      'source_project': state.selectedProject,
      'channels': [
        for (final ch in channels)
          {
            'channel_id': ch['channel_id'],
            'language': ch['language'],
            'title': ch['title'],
            'handle': ch['handle'],
            'description': ch['description'],
            'keywords': ch['keywords'],
            'brand_category': ch['brand_category'],
            'overall_style': ch['overall_style'],
            'channel_style': ch['channel_style'],
            'vibe': ch['vibe'],
            'visual_style': ch['visual_style'],
            'enabled': ch['enabled'],
          }
      ]
    };

    final jsonString = jsonEncode(exportData);
    
    // Try to save to file
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'channels_export_${state.selectedProject}_$timestamp.json';
      
      final result = await FilePicker.platform.saveFile(
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        await File(result).writeAsString(jsonString);
        _showSnack('✓ Channels exported to file: $fileName');
      } else {
        // If file picker cancelled, copy to clipboard as fallback
        Clipboard.setData(ClipboardData(text: jsonString));
        _showSnack('✓ Channels exported to clipboard (${channels.length} channels).');
      }
    } catch (e) {
      // Fallback to clipboard
      Clipboard.setData(ClipboardData(text: jsonString));
      _showSnack('✓ Channels exported to clipboard (${channels.length} channels). File save failed: $e');
    }
  }

  void _importChannels(AppState state) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final String jsonString;
      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      } else {
        _showSnack('Cannot read file.');
        return;
      }
      final importData = jsonDecode(jsonString) as Map<String, dynamic>;

      final importedChannels = (importData['channels'] as List?)?.cast<Map>() ?? [];
      if (importedChannels.isEmpty) {
        _showSnack('No channels found in import file.');
        return;
      }

      final project = state.activeProject;
      if (project == null) {
        _showSnack('Load a project first.');
        return;
      }

      // Show confirmation dialog
      if (!mounted) return;
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Channels'),
          content: Text('Import ${importedChannels.length} channels? Existing channels with same IDs will be updated.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      ) ?? false;

      if (!shouldImport) return;

      final existingChannels = (project['channels'] as List?)?.cast<Map>() ?? [];
      final existingIds = {for (final ch in existingChannels) (ch as Map)['channel_id']: ch};

      for (final importedCh in importedChannels) {
        final channelId = importedCh['channel_id'] as String?;
        if (channelId != null) {
          if (existingIds.containsKey(channelId)) {
            // Update existing
            final existing = existingIds[channelId] as Map<String, dynamic>;
            existing['language'] = importedCh['language'];
            existing['title'] = importedCh['title'];
            existing['handle'] = importedCh['handle'];
            existing['description'] = importedCh['description'];
            existing['keywords'] = importedCh['keywords'];
            existing['brand_category'] = importedCh['brand_category'];
            existing['overall_style'] = importedCh['overall_style'];
            existing['channel_style'] = importedCh['channel_style'];
            existing['vibe'] = importedCh['vibe'];
            existing['visual_style'] = importedCh['visual_style'];
            existing['enabled'] = importedCh['enabled'];
          } else {
            // Add new
            existingChannels.add({
              'channel_id': importedCh['channel_id'],
              'language': importedCh['language'] ?? 'en',
              'title': importedCh['title'] ?? 'Imported Channel',
              'handle': importedCh['handle'] ?? '',
              'description': importedCh['description'] ?? '',
              'keywords': importedCh['keywords'] ?? '',
              'brand_category': importedCh['brand_category'] ?? '',
              'overall_style': importedCh['overall_style'] ?? 'cinematic',
              'channel_style': importedCh['channel_style'] ?? '',
              'vibe': importedCh['vibe'] ?? 'experimental',
              'visual_style': importedCh['visual_style'] ?? 'stylized',
              'enabled': importedCh['enabled'] ?? true,
            });
          }
        }
      }

      project['channels'] = existingChannels;
      state.touch();
      _showSnack('✓ Imported ${importedChannels.length} channels successfully.');
      
      // Trigger autosave
      _scheduleAutosave(state);
    } catch (e) {
      _showSnack('❌ Error importing channels: $e');
    }
  }

  void _exportLyrics(AppState state) async {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }

    final lyrics = (project['lyrics'] as Map?) ?? {};
    final exportData = {
      'version': '1.0',
      'export_date': DateTime.now().toIso8601String(),
      'source_project': state.selectedProject,
      'lyrics': lyrics,
    };

    final jsonString = jsonEncode(exportData);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'lyrics_export_${state.selectedProject}_$timestamp.json';
      
      final result = await FilePicker.platform.saveFile(
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        await File(result).writeAsString(jsonString);
        _showSnack('✓ Lyrics exported to file: $fileName');
      } else {
        Clipboard.setData(ClipboardData(text: jsonString));
        _showSnack('✓ Lyrics exported to clipboard.');
      }
    } catch (e) {
      Clipboard.setData(ClipboardData(text: jsonString));
      _showSnack('✓ Lyrics exported to clipboard. File save failed: $e');
    }
  }

  void _importLyrics(AppState state) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final String jsonString;
      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      } else {
        _showSnack('Cannot read file.');
        return;
      }
      final importData = jsonDecode(jsonString) as Map<String, dynamic>;
      final importedLyrics = importData['lyrics'] as Map?;

      if (importedLyrics == null) {
        _showSnack('No lyrics found in import file.');
        return;
      }

      final project = state.activeProject;
      if (project == null) {
        _showSnack('Load a project first.');
        return;
      }

      if (!mounted) return;
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Lyrics'),
          content: const Text('Replace existing lyrics with imported data?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      ) ?? false;

      if (!shouldImport) return;

      project['lyrics'] = importedLyrics;
      state.touch();
      _showSnack('✓ Lyrics imported successfully.');
      _scheduleAutosave(state);
    } catch (e) {
      _showSnack('❌ Error importing lyrics: $e');
    }
  }

  void _exportStoryboard(AppState state) async {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }

    final storyboard = (project['storyboard'] as Map?) ?? {};
    final exportData = {
      'version': '1.0',
      'export_date': DateTime.now().toIso8601String(),
      'source_project': state.selectedProject,
      'storyboard': storyboard,
    };

    final jsonString = jsonEncode(exportData);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'storyboard_export_${state.selectedProject}_$timestamp.json';
      
      final result = await FilePicker.platform.saveFile(
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        await File(result).writeAsString(jsonString);
        _showSnack('✓ Storyboard exported to file: $fileName');
      } else {
        Clipboard.setData(ClipboardData(text: jsonString));
        _showSnack('✓ Storyboard exported to clipboard.');
      }
    } catch (e) {
      Clipboard.setData(ClipboardData(text: jsonString));
      _showSnack('✓ Storyboard exported to clipboard. File save failed: $e');
    }
  }

  void _importStoryboard(AppState state) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final String jsonString;
      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      } else {
        _showSnack('Cannot read file.');
        return;
      }
      final importData = jsonDecode(jsonString) as Map<String, dynamic>;
      final importedStoryboard = importData['storyboard'] as Map?;

      if (importedStoryboard == null) {
        _showSnack('No storyboard found in import file.');
        return;
      }

      final project = state.activeProject;
      if (project == null) {
        _showSnack('Load a project first.');
        return;
      }

      if (!mounted) return;
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Storyboard'),
          content: const Text('Replace existing storyboard with imported data?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      ) ?? false;

      if (!shouldImport) return;

      project['storyboard'] = importedStoryboard;
      state.touch();
      _showSnack('✓ Storyboard imported successfully.');
      _scheduleAutosave(state);
    } catch (e) {
      _showSnack('❌ Error importing storyboard: $e');
    }
  }

  void _exportCharacters(AppState state) async {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }

    final characters = (project['characters'] as List?)?.cast<Map>() ?? [];
    final exportData = {
      'version': '1.0',
      'export_date': DateTime.now().toIso8601String(),
      'source_project': state.selectedProject,
      'characters': characters,
    };

    final jsonString = jsonEncode(exportData);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'characters_export_${state.selectedProject}_$timestamp.json';
      
      final result = await FilePicker.platform.saveFile(
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        await File(result).writeAsString(jsonString);
        _showSnack('✓ Characters exported to file: $fileName');
      } else {
        Clipboard.setData(ClipboardData(text: jsonString));
        _showSnack('✓ Characters exported to clipboard.');
      }
    } catch (e) {
      Clipboard.setData(ClipboardData(text: jsonString));
      _showSnack('✓ Characters exported to clipboard. File save failed: $e');
    }
  }

  void _importCharacters(AppState state) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final String jsonString;
      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      } else {
        _showSnack('Cannot read file.');
        return;
      }
      final importData = jsonDecode(jsonString) as Map<String, dynamic>;
      final importedCharacters = (importData['characters'] as List?)?.cast<Map>() ?? [];

      if (importedCharacters.isEmpty) {
        _showSnack('No characters found in import file.');
        return;
      }

      final project = state.activeProject;
      if (project == null) {
        _showSnack('Load a project first.');
        return;
      }

      if (!mounted) return;
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Characters'),
          content: Text('Import ${importedCharacters.length} characters? Existing characters with same IDs will be updated.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      ) ?? false;

      if (!shouldImport) return;

      final existingCharacters = (project['characters'] as List?)?.cast<Map>() ?? [];
      final existingIds = {for (final ch in existingCharacters) (ch as Map)['id']: ch};

      for (final importedCh in importedCharacters) {
        final charId = importedCh['id'] as String?;
        if (charId != null) {
          if (existingIds.containsKey(charId)) {
            final existing = existingIds[charId] as Map<String, dynamic>;
            existing.addAll(importedCh as Map<String, dynamic>);
          } else {
            existingCharacters.add(importedCh);
          }
        }
      }

      project['characters'] = existingCharacters;
      state.touch();
      _showSnack('✓ Imported ${importedCharacters.length} characters successfully.');
      _scheduleAutosave(state);
    } catch (e) {
      _showSnack('❌ Error importing characters: $e');
    }
  }

  void _exportFullProject(AppState state) async {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }

    final exportData = {
      'version': '1.0',
      'export_date': DateTime.now().toIso8601String(),
      'project_name': state.selectedProject,
      'project_data': project,
    };

    final jsonString = jsonEncode(exportData);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'project_backup_${state.selectedProject}_$timestamp.json';
      
      final result = await FilePicker.platform.saveFile(
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        await File(result).writeAsString(jsonString);
        _showSnack('✓ Full project backup exported: $fileName');
      } else {
        Clipboard.setData(ClipboardData(text: jsonString));
        _showSnack('✓ Project data exported to clipboard.');
      }
    } catch (e) {
      Clipboard.setData(ClipboardData(text: jsonString));
      _showSnack('✓ Project exported to clipboard. File save failed: $e');
    }
  }

  void _importFullProject(AppState state) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final String jsonString;
      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonString = await File(file.path!).readAsString();
      } else {
        _showSnack('Cannot read file.');
        return;
      }
      final importData = jsonDecode(jsonString) as Map<String, dynamic>;
      final importedProject = importData['project_data'] as Map?;

      if (importedProject == null) {
        _showSnack('No project data found in import file.');
        return;
      }

      if (!mounted) return;
      final shouldImport = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Full Project'),
          content: const Text('This will replace all current project data. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import'),
            ),
          ],
        ),
      ) ?? false;

      if (!shouldImport) return;

      // Replace active project with imported data
      for (final key in state.activeProject!.keys.toList()) {
        state.activeProject!.remove(key);
      }
      state.activeProject!.addAll(importedProject as Map<String, dynamic>);
      state.touch();
      _showSnack('✓ Full project imported successfully.');
      _scheduleAutosave(state);
    } catch (e) {
      _showSnack('❌ Error importing project: $e');
    }
  }

  void _syncAllChannels(AppState state) async {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }

    final youtubeSettings = state.settings['youtube'] as Map?;
    final apiKey = youtubeSettings?['api_key']?.toString() ?? '';
    final channels = (project['channels'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (channels.isEmpty) {
      _showSnack('No channels configured yet.');
      return;
    }

    _showSnack('Syncing channels with per-channel OAuth tokens...');

    int updatedCount = 0;
    int failedCount = 0;

    for (final ch in channels) {
      final channelId = ch['channel_id']?.toString() ?? '';
      if (channelId.isEmpty) {
        failedCount++;
        continue;
      }

      final accessToken = await _ensureFreshChannelAccessToken(state, ch, silent: true);
      final resolvedChannelId = channelId.startsWith('handle:')
          ? await _resolveYouTubeHandleToChannelId(channelId.replaceFirst('handle:', ''), apiKey: apiKey, oauthToken: accessToken)
          : channelId;

      if (resolvedChannelId == null || resolvedChannelId.isEmpty) {
        failedCount++;
        continue;
      }

      final query = {
        'part': 'snippet,statistics,contentDetails,brandingSettings,status,topicDetails,localizations',
        'id': resolvedChannelId,
      };
      if (apiKey.isNotEmpty && (accessToken == null || accessToken.isEmpty)) {
        query['key'] = apiKey;
      }

      final url = Uri.https('www.googleapis.com', '/youtube/v3/channels', query);
      final response = await http.get(
        url,
        headers: accessToken != null && accessToken.isNotEmpty
            ? {'Authorization': 'Bearer $accessToken'}
            : {},
      );

      if (response.statusCode != 200) {
        failedCount++;
        continue;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (payload['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (items.isEmpty) {
        failedCount++;
        continue;
      }

      final ytChannel = items.first;
      final snippet = ytChannel['snippet'] as Map<String, dynamic>?;
      final stats = ytChannel['statistics'] as Map<String, dynamic>?;
      final branding = ytChannel['brandingSettings'] as Map<String, dynamic>?;
      final channelBranding = branding?['channel'] as Map<String, dynamic>?;
      final status = ytChannel['status'] as Map<String, dynamic>?;
      final contentDetails = ytChannel['contentDetails'] as Map<String, dynamic>?;
      final topicDetails = ytChannel['topicDetails'] as Map<String, dynamic>?;

      ch['youtube_channel_id'] = resolvedChannelId;
      ch['title'] = (ch['title']?.toString().isNotEmpty == true) ? ch['title'] : (snippet?['title']?.toString() ?? '');
      ch['description'] = (ch['description']?.toString().isNotEmpty == true) ? ch['description'] : (snippet?['description']?.toString() ?? '');
      ch['handle'] = (ch['handle']?.toString().isNotEmpty == true) ? ch['handle'] : (snippet?['customUrl']?.toString() ?? '');
      ch['keywords'] = (ch['keywords']?.toString().isNotEmpty == true) ? ch['keywords'] : (channelBranding?['keywords']?.toString() ?? '');

      ch['yt_custom_url'] = snippet?['customUrl']?.toString() ?? '';
      ch['yt_country'] = snippet?['country']?.toString() ?? '';
      ch['yt_default_language'] = snippet?['defaultLanguage']?.toString() ?? '';
      ch['yt_published_at'] = snippet?['publishedAt']?.toString() ?? '';
      ch['yt_subscriber_count'] = int.tryParse(stats?['subscriberCount']?.toString() ?? '0') ?? 0;
      ch['yt_video_count'] = int.tryParse(stats?['videoCount']?.toString() ?? '0') ?? 0;
      ch['yt_view_count'] = int.tryParse(stats?['viewCount']?.toString() ?? '0') ?? 0;
      ch['yt_hidden_subscriber_count'] = stats?['hiddenSubscriberCount'] == true;
      ch['yt_is_linked'] = status?['isLinked'] == true;
      ch['yt_made_for_kids'] = status?['madeForKids'];
      ch['yt_self_declared_made_for_kids'] = status?['selfDeclaredMadeForKids'];
      ch['yt_privacy_status'] = status?['privacyStatus']?.toString() ?? '';
      ch['yt_topic_ids'] = (topicDetails?['topicIds'] as List?)?.cast<dynamic>() ?? [];
      ch['yt_topic_categories'] = (topicDetails?['topicCategories'] as List?)?.cast<dynamic>() ?? [];
      ch['yt_localizations'] = (ytChannel['localizations'] as Map<String, dynamic>?) ?? {};
      ch['yt_branding'] = {
        'keywords': channelBranding?['keywords']?.toString() ?? '',
        'channel': channelBranding ?? {},
        'image': branding?['image'] ?? {},
        'watch': branding?['watch'] ?? {},
      };
      ch['yt_uploads_playlist'] =
          (contentDetails?['relatedPlaylists'] as Map<String, dynamic>?)?['uploads']?.toString() ?? '';
      ch['yt_sync_source'] = accessToken != null && accessToken.isNotEmpty ? 'channel_oauth' : 'api_key';
      ch['yt_synced_at'] = DateTime.now().toIso8601String();
      updatedCount++;
    }

    project['channels'] = channels;
    state.touch();
    _scheduleAutosave(state);
    _showSnack('✅ Channel sync complete. Updated: $updatedCount, failed: $failedCount');
  }

  void _ensureChannelOAuthHydration(AppState state) {
    final project = state.activeProject;
    final projectName = state.selectedProject;
    if (project == null || projectName == null) return;
    if (_oauthHydratedProjectName == projectName) return;
    _oauthHydratedProjectName = projectName;
    unawaited(_refreshExpiringChannelAccessTokens(state, silent: true));
  }

  Map<String, dynamic> _ensureProjectOAuthStore(Map<String, dynamic> project) {
    final existing = project['youtube_oauth'];
    if (existing is Map) {
      final typed = existing.cast<String, dynamic>();
      typed.putIfAbsent('channels', () => <String, dynamic>{});
      typed.putIfAbsent('token_refresh_policy', () => {
            'threshold_ratio': _tokenRefreshThresholdRatio,
            'default_access_token_lifetime_seconds': _defaultYouTubeAccessTokenLifetimeSeconds,
          });
      project['youtube_oauth'] = typed;
      return typed;
    }
    final created = <String, dynamic>{
      'channels': <String, dynamic>{},
      'token_refresh_policy': {
        'threshold_ratio': _tokenRefreshThresholdRatio,
        'default_access_token_lifetime_seconds': _defaultYouTubeAccessTokenLifetimeSeconds,
      },
    };
    project['youtube_oauth'] = created;
    return created;
  }

  Map<String, dynamic>? _channelOAuthRecord(Map<String, dynamic> project, String channelId, {bool create = false}) {
    final oauth = _ensureProjectOAuthStore(project);
    final channels = (oauth['channels'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    oauth['channels'] = channels;
    final existing = channels[channelId];
    if (existing is Map) {
      return existing.cast<String, dynamic>();
    }
    if (!create) return null;
    final created = <String, dynamic>{
      'channel_id': channelId,
      'refresh_token': '',
      'access_token': '',
      'access_token_obtained_at': '',
      'access_token_expires_at': '',
      'access_token_expires_in_seconds': _defaultYouTubeAccessTokenLifetimeSeconds,
      'token_type': 'Bearer',
      'scope': '',
      'last_refresh_at': '',
      'status': 'not_configured',
      'last_error': '',
    };
    channels[channelId] = created;
    return created;
  }

  bool _isAccessTokenExpiring(Map<String, dynamic> tokenRecord) {
    final accessToken = tokenRecord['access_token']?.toString() ?? '';
    final expiresAtRaw = tokenRecord['access_token_expires_at']?.toString() ?? '';
    if (accessToken.isEmpty || expiresAtRaw.isEmpty) return true;
    final expiresAt = DateTime.tryParse(expiresAtRaw)?.toUtc();
    if (expiresAt == null) return true;
    final now = DateTime.now().toUtc();
    final expiresInSeconds = int.tryParse(tokenRecord['access_token_expires_in_seconds']?.toString() ?? '') ??
        _defaultYouTubeAccessTokenLifetimeSeconds;
    final thresholdSeconds = (expiresInSeconds * _tokenRefreshThresholdRatio).round();
    return expiresAt.difference(now).inSeconds <= thresholdSeconds;
  }

  Future<String?> _ensureFreshChannelAccessToken(
    AppState state,
    Map<String, dynamic> channel, {
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    final project = state.activeProject;
    if (project == null) return null;
    final channelId = channel['channel_id']?.toString();
    if (channelId == null || channelId.isEmpty) return null;
    final record = _channelOAuthRecord(project, channelId);
    if (record == null) return null;
    if (forceRefresh || _isAccessTokenExpiring(record)) {
      return _refreshChannelAccessToken(state, channel, silent: silent);
    }
    return record['access_token']?.toString();
  }

  Future<void> _refreshExpiringChannelAccessTokens(AppState state, {bool silent = false}) async {
    final project = state.activeProject;
    if (project == null) return;
    final channels = (project['channels'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (final channel in channels) {
      final channelId = channel['channel_id']?.toString();
      if (channelId == null || channelId.isEmpty) continue;
      final record = _channelOAuthRecord(project, channelId);
      if (record == null) continue;
      final refreshToken = record['refresh_token']?.toString() ?? '';
      if (refreshToken.isEmpty) continue;
      if (_isAccessTokenExpiring(record)) {
        await _refreshChannelAccessToken(state, channel, silent: silent);
      }
    }
  }

  Future<String?> _refreshChannelAccessToken(
    AppState state,
    Map<String, dynamic> channel, {
    bool silent = false,
  }) async {
    final project = state.activeProject;
    if (project == null) return null;
    final channelId = channel['channel_id']?.toString();
    if (channelId == null || channelId.isEmpty) return null;
    final record = _channelOAuthRecord(project, channelId, create: true);
    if (record == null) return null;

    final refreshToken = record['refresh_token']?.toString() ?? '';
    if (refreshToken.isEmpty) return null;
    final youtubeSettings = state.settings['youtube'] as Map?;
    final clientId = youtubeSettings?['client_id']?.toString() ?? '';
    final clientSecret = youtubeSettings?['client_secret']?.toString() ?? '';
    if (clientId.isEmpty || clientSecret.isEmpty) {
      if (!silent) {
        _showSnack('Missing YouTube client credentials in Settings.');
      }
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );
      if (response.statusCode != 200) {
        record['status'] = 'error';
        record['last_error'] = 'HTTP ${response.statusCode}: ${response.body}';
        if (!silent) {
          _showSnack('Token refresh failed for $channelId (HTTP ${response.statusCode}).');
        }
        return null;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = payload['access_token']?.toString() ?? '';
      if (accessToken.isEmpty) return null;
      final now = DateTime.now().toUtc();
      final expiresIn = int.tryParse(payload['expires_in']?.toString() ?? '') ??
          _defaultYouTubeAccessTokenLifetimeSeconds;
      record['access_token'] = accessToken;
      record['access_token_obtained_at'] = now.toIso8601String();
      record['access_token_expires_in_seconds'] = expiresIn;
      record['access_token_expires_at'] = now.add(Duration(seconds: expiresIn)).toIso8601String();
      record['token_type'] = payload['token_type']?.toString() ?? 'Bearer';
      record['scope'] = payload['scope']?.toString() ?? record['scope']?.toString() ?? '';
      record['last_refresh_at'] = now.toIso8601String();
      record['status'] = 'connected';
      record['last_error'] = '';
      channel['yt_oauth_status'] = 'connected';
      channel['yt_oauth_updated_at'] = now.toIso8601String();
      state.touch();
      _scheduleAutosave(state);
      if (!silent) {
        _showSnack('✅ Refreshed access token for channel $channelId');
      }
      return accessToken;
    } catch (e) {
      record['status'] = 'error';
      record['last_error'] = e.toString();
      if (!silent) {
        _showSnack('Token refresh failed for $channelId: $e');
      }
      return null;
    }
  }

  /// Resolves a YouTube @handle to its channel ID using the YouTube Data API v3
  Future<String?> _resolveYouTubeHandleToChannelId(String handle, {String? apiKey, String? oauthToken}) async {
    try {
      // Remove @ if present
      final cleanHandle = handle.startsWith('@') ? handle.substring(1) : handle;
      
      if (cleanHandle.isEmpty) return null;

      if ((apiKey == null || apiKey.isEmpty) && (oauthToken == null || oauthToken.isEmpty)) {
        return null;
      }

      // Try using the youtube.com/@handle format via search API
      final query = {
        'q': '@$cleanHandle',
        'type': 'channel',
        'part': 'snippet',
        'maxResults': '5',
      };
      http.Response response;
      if (oauthToken != null && oauthToken.isNotEmpty) {
        final oauthUrl = Uri.https('www.googleapis.com', '/youtube/v3/search', query);
        response = await http.get(oauthUrl, headers: {'Authorization': 'Bearer $oauthToken'});
      } else {
        final keyUrl = Uri.https('www.googleapis.com', '/youtube/v3/search', {
          ...query,
          'key': apiKey!,
        });
        response = await http.get(keyUrl);
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        for (final item in items) {
          final snippet = item['snippet'] as Map<String, dynamic>?;
          final channelTitle = snippet?['title'] as String? ?? '';
          
          // Look for exact match in title that starts with @handle
          if (channelTitle.toLowerCase().contains(cleanHandle.toLowerCase())) {
            // Fetch the channel to get the actual customUrl
            final resourceId = item['id'] as Map<String, dynamic>?;
            final channelId = resourceId?['channelId'] as String?;
            
            if (channelId != null) {
              // Validate by fetching the channel details
              http.Response detailResponse;
              if (oauthToken != null && oauthToken.isNotEmpty) {
                final detailUrl = Uri.https('www.googleapis.com', '/youtube/v3/channels', {
                  'id': channelId,
                  'part': 'snippet',
                });
                detailResponse = await http.get(detailUrl, headers: {'Authorization': 'Bearer $oauthToken'});
              } else {
                final detailUrl = Uri.https('www.googleapis.com', '/youtube/v3/channels', {
                  'id': channelId,
                  'part': 'snippet',
                  'key': apiKey!,
                });
                detailResponse = await http.get(detailUrl);
              }
              if (detailResponse.statusCode == 200) {
                final detailData = jsonDecode(detailResponse.body) as Map<String, dynamic>;
                final detailItems = (detailData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                
                if (detailItems.isNotEmpty) {
                  final detailSnippet = detailItems.first['snippet'] as Map<String, dynamic>?;
                  final customUrl = detailSnippet?['customUrl'] as String? ?? '';
                  
                  // Check if this matches our handle
                  if (customUrl.toLowerCase() == cleanHandle.toLowerCase() || 
                      customUrl.toLowerCase() == '@$cleanHandle'.toLowerCase()) {
                    return channelId;
                  }
                }
              }
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  void _showAddChannelDialog(AppState state) async {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }

    final channelInputController = TextEditingController();
    final channelTitleController = TextEditingController();
    
    if (!mounted) return;
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manually Add Channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: channelInputController,
              decoration: const InputDecoration(
                labelText: 'YouTube Channel ID or @Handle',
                hintText: 'Use Channel ID (UC...) or @handle (e.g., @TED)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'If using @handle: app will resolve it to the actual channel ID during sync',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: channelTitleController,
              decoration: const InputDecoration(
                labelText: 'Channel Title',
                hintText: 'Leave blank to auto-fetch',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    ) ?? false;

    if (!shouldAdd) return;

    final channelInput = channelInputController.text.trim();
    final channelTitle = channelTitleController.text.trim();

    if (channelInput.isEmpty) {
      _showSnack('Channel ID or @Handle cannot be empty.');
      return;
    }

    final existingChannels = (project['channels'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    // Determine if input is @handle or channel ID
    final isHandle = channelInput.startsWith('@') || !channelInput.startsWith('UC');
    String? resolvedChannelId = isHandle ? null : channelInput;
    String inputHandle = isHandle ? (channelInput.startsWith('@') ? channelInput : '@$channelInput') : '';

    // If input is a handle, try to resolve it
    if (isHandle && resolvedChannelId == null) {
      _showSnack('Resolving @handle: $inputHandle...');
      final youtubeSettings = state.settings['youtube'] as Map?;
      final apiKey = youtubeSettings?['api_key']?.toString();
      final oauthToken = youtubeSettings?['oauth_token']?.toString();
      resolvedChannelId = await _resolveYouTubeHandleToChannelId(
        channelInput,
        apiKey: apiKey,
        oauthToken: oauthToken,
      );
      
      if (resolvedChannelId == null) {
        _showSnack('⚠️ Could not resolve @handle: $inputHandle\n\nThe handle will be stored and resolved during next sync. Make sure it\'s a valid YouTube channel handle.');
        // Continue anyway - we'll try to resolve during sync
        resolvedChannelId = 'handle:${channelInput.replaceFirst(RegExp('^@'), '')}';
      } else {
        _showSnack('✓ Resolved @handle to channel ID: $resolvedChannelId');
      }
    }

    final finalChannelId = resolvedChannelId ?? channelInput;

    // Check if channel already exists
    if (existingChannels.any((ch) => ch['channel_id'] == finalChannelId)) {
      _showSnack('This channel is already in the project.');
      return;
    }

    // Also check if this handle already exists (if it was input as handle)
    if (inputHandle.isNotEmpty &&
        existingChannels.any((ch) => (ch['handle'] as String?)?.toLowerCase() == inputHandle.toLowerCase())) {
      _showSnack('A channel with this handle already exists in the project.');
      return;
    }

    // Add new channel
    final lyrics = _ensureLyricsStructure(project);
    final defaultLang = ((lyrics['languages'] as List?)?.isNotEmpty ?? false)
        ? (lyrics['languages'] as List).first.toString()
        : 'en';

    existingChannels.add({
      'channel_id': finalChannelId,
      'youtube_channel_id': '',
      'language': defaultLang,
      'title': channelTitle.isEmpty ? (inputHandle.isNotEmpty ? inputHandle : 'Manual Channel') : channelTitle,
      'handle': inputHandle,
      'description': '',
      'keywords': '',
      'brand_category': '',
      'overall_style': 'cinematic',
      'channel_style': '',
      'vibe': 'experimental',
      'visual_style': 'stylized',
      'enabled': true,
      'yt_oauth_status': 'not_configured',
    });

    project['channels'] = existingChannels;
    state.touch();
    _scheduleAutosave(state);
    _showSnack('✅ Channel added! ${isHandle ? 'Handle will be resolved during sync.' : ''}');
  }

  Map<String, Map<String, String>> _generateChannelDataFromPattern({
    required String prefix,
    required String baseName,
    required String rangePattern,
  }) {
    // Returns map of channel_id -> {channel_id, handle}
    final channelData = <String, Map<String, String>>{};
    
    // Parse range pattern to extract start, end, and padding
    final pattern = rangePattern.replaceAll(',', '').trim();
    
    // Split by "..." to get components
    final parts = pattern.split('...').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    
    if (parts.isEmpty) {
      return channelData; // Invalid pattern
    }

    if (parts.length == 1) {
      // Single value like "5" or "01"
      final val = parts[0];
      final channelId = '$prefix$baseName$val';
      final handle = prefix.isNotEmpty && baseName.isNotEmpty 
        ? '@${prefix}_${baseName}_$val'
        : '@${baseName}_$val';
      channelData[channelId] = {
        'channel_id': channelId,
        'handle': handle,
      };
      return channelData;
    }

    // Multiple parts: extract start and end
    String start = parts[0];
    String end = parts.isNotEmpty ? parts.last : parts[0];

    // Determine if padding is needed (e.g., "01" vs "1")
    int? startNum = int.tryParse(start);
    int? endNum = int.tryParse(end);

    if (startNum == null || endNum == null) {
      return channelData; // Invalid numbers
    }

    final padWidth = start.startsWith('0') ? start.length : 0;

    // Generate the range
    for (int i = startNum; i <= endNum; i++) {
      final numStr = padWidth > 0 ? i.toString().padLeft(padWidth, '0') : i.toString();
      final channelId = '$prefix$baseName$numStr';
      final handle = prefix.isNotEmpty && baseName.isNotEmpty
        ? '@${prefix}_${baseName}_$numStr'
        : '@${baseName}_$numStr';
      channelData[channelId] = {
        'channel_id': channelId,
        'handle': handle,
      };
    }

    return channelData;
  }

  void _showBatchChannelDialog(AppState state) async {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }

    final prefixController = TextEditingController(text: 'UC');
    final baseNameController = TextEditingController();
    final rangeController = TextEditingController(text: '01 ... 50');
    
    if (!mounted) return;
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Channels by Pattern'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate multiple channel IDs using a pattern.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: prefixController,
                decoration: const InputDecoration(
                  labelText: 'Prefix (e.g., "UC")',
                  hintText: 'Optional prefix for channel IDs',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: baseNameController,
                decoration: const InputDecoration(
                  labelText: 'Base Name (required)',
                  hintText: 'e.g., "abc" or "myChannel"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rangeController,
                decoration: InputDecoration(
                  labelText: 'Range Pattern (required)',
                  hintText: 'e.g., "01 ... 50" or "1 ... 100"',
                  border: const OutlineInputBorder(),
                  helperText: 'Formats:\n• "01 ... 09 ... 29" → 01, 02, ..., 09, 10, ..., 29\n• "1 ... 50" → 1, 2, ..., 50\n• "001 ... 999" → 001, 002, ..., 999',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Examples:', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 6),
                    Text('• Prefix: "UC", Base: "abc", Range: "01 ... 29"\n→ UCabc01, UCabc02, ..., UCabc29',
                      style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text('• Prefix: "", Base: "channel", Range: "1 ... 10"\n→ channel1, channel2, ..., channel10',
                      style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    ) ?? false;

    if (!shouldAdd) return;

    final prefix = prefixController.text.trim();
    final baseName = baseNameController.text.trim();
    final range = rangeController.text.trim();

    if (baseName.isEmpty || range.isEmpty) {
      _showSnack('Base name and range are required.');
      return;
    }

    // Generate channel data with both IDs and handles
    final generatedChannels = _generateChannelDataFromPattern(
      prefix: prefix,
      baseName: baseName,
      rangePattern: range,
    );

    if (generatedChannels.isEmpty) {
      _showSnack('Could not parse range pattern. Use format like "01 ... 50" or "1 ... 100".');
      return;
    }

    // Add generated channels to project
    final existingChannels = (project['channels'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final existingIds = {for (final ch in existingChannels) ch['channel_id']: true};
    final existingHandles = {for (final ch in existingChannels) (ch['handle'] as String?)?.toLowerCase() ?? '': ch};

    int addedCount = 0;
    int skippedCount = 0;
    int mergedCount = 0;

    final lyrics = _ensureLyricsStructure(project);
    final defaultLang = ((lyrics['languages'] as List?)?.isNotEmpty ?? false)
        ? (lyrics['languages'] as List).first.toString()
        : 'en';

    for (final channelData in generatedChannels.values) {
      final channelId = channelData['channel_id']!;
      final handle = channelData['handle']!;

      // Check if channel already exists by ID
      if (existingIds.containsKey(channelId)) {
        skippedCount++;
        continue;
      }

      // Check if channel with same handle already exists (merge data)
      final handleLower = handle.toLowerCase();
      final existingByHandle = existingHandles[handleLower];
      if (existingByHandle != null && (existingByHandle['youtube_channel_id'] == null || (existingByHandle['youtube_channel_id'] as String).isEmpty)) {
        // Merge: update the existing channel with the YouTube channel ID
        existingByHandle['youtube_channel_id'] = channelId;
        mergedCount++;
        continue;
      }

      // Add as new channel
      existingChannels.add({
        'channel_id': channelId,
        'youtube_channel_id': '',  // Will be filled during sync
        'language': defaultLang,
        'title': '',  // Will be populated from YouTube sync
        'handle': handle,
        'description': '',
        'keywords': '',
        'brand_category': '',
        'overall_style': 'cinematic',
        'channel_style': '',
        'vibe': 'experimental',
        'visual_style': 'stylized',
        'enabled': true,
        'yt_oauth_status': 'not_configured',
      });
      addedCount++;
    }

    project['channels'] = existingChannels;
    state.touch();
    _scheduleAutosave(state);

    String mergeMsg = mergedCount > 0 ? '\n• Merged with existing: $mergedCount' : '';
    _showSnack('✅ Generated channels added!\n• Added: $addedCount\n• Skipped (already exist): $skippedCount$mergeMsg\n• Total in project: ${existingChannels.length}\n\n💡 Next: Click "Sync All" to fetch metadata from YouTube.');
  }

  void _testOAuthConnection(AppState state) async {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }
    final channels = (project['channels'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (channels.isEmpty) {
      _showSnack('Add at least one channel first.');
      return;
    }
    final accessToken = await _ensureFreshChannelAccessToken(state, channels.first);
    if (accessToken == null || accessToken.isEmpty) {
      _showSnack('No per-channel OAuth token found. Use "Fetch refresh token" on a channel card first.');
      return;
    }

    _showSnack('Testing OAuth token connection...');

    try {
      // Test 1: Get authenticated user info
      final userUrl = Uri.https('www.googleapis.com', '/youtube/v3/channels', {
        'part': 'id,snippet',
        'mine': 'true',
      });

      final userResponse = await http.get(
        userUrl,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (userResponse.statusCode == 401) {
        _showSnack('❌ OAuth token is invalid or expired. Re-authorize in Settings.');
        return;
      }

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body) as Map<String, dynamic>;
        final items = (userData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        if (items.isEmpty) {
          _showSnack('⚠️ Token valid, but no channels accessible. Check Google permissions.');
          return;
        }

        final primaryChannel = items.first;
        final channelTitle = primaryChannel['snippet']?['title'] ?? 'Unknown';

        _showSnack('✅ OAuth Connection Valid!\n• Primary Channel: $channelTitle\n• Total accessible: ${items.length} channel(s)\n\nNote: If you have 30+ channels, some may require special account setup.');
        return;
      } else {
        final errorBody = jsonDecode(userResponse.body) as Map<String, dynamic>?;
        final errorMsg = errorBody?['error']?['message'] ?? 'Unknown error';
        _showSnack('❌ Connection failed (HTTP ${userResponse.statusCode}): $errorMsg');
      }
    } catch (e) {
      _showSnack('❌ Error testing connection: $e');
    }
  }


  Widget _buildSunoControlSpace(AppState state, Map<String, dynamic> project, List<String> availableLangs) {
    final generationMoods = (project['generation_moods'] as Map?)?.cast<String, dynamic>() ?? {
      'music_mood': 'cinematic, inspiring',
      'image_mood': 'photorealistic, cinematic',
      'video_mood': 'smooth transitions, dynamic',
    };
    
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note),
                const SizedBox(width: 8),
                Text('Suno Song Generation', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Generate songs for all channels using Suno API. Songs will be created according to each channel\'s language, style, and mood settings.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Mood Combination:', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Music Mood: ${generationMoods['music_mood'] ?? 'Not set'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Combined with each channel\'s tone + vibe → final song generation',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: state.settings['suno']?['token'] != null && (state.settings['suno']['token'] as String).isNotEmpty
                      ? () => _generateSongsForAllChannels(state, project)
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Generate for All Channels'),
                ),
                OutlinedButton.icon(
                  onPressed: state.settings['suno']?['token'] != null && (state.settings['suno']['token'] as String).isNotEmpty
                      ? () => _generateSongsForLanguages(state, project, availableLangs)
                      : null,
                  icon: const Icon(Icons.language),
                  label: const Text('Generate by Language'),
                ),
                OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Suno generation status tracking coming soon')),
                  ),
                  icon: const Icon(Icons.schedule),
                  label: const Text('View Status'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openYouTubeChannelCreation(AppState state) {
    final youtubeSettings = state.settings['youtube'] as Map?;
    final accountEmail = youtubeSettings?['account_email'] as String?;
    final brandChannelId = youtubeSettings?['brand_channel_id'] as String?;

    if (accountEmail == null || accountEmail.isEmpty) {
      _showSnack('Set your YouTube account email in Settings first.');
      return;
    }

    // Open YouTube channel switcher
    final url = 'https://www.youtube.com/channel_switcher';
    _launchUrl(url);
  }

  void _showFetchRefreshTokenDialog(AppState state, Map<String, dynamic> channel) async {
    final youtubeSettings = state.settings['youtube'] as Map?;
    final clientId = youtubeSettings?['client_id']?.toString() ?? '';
    final clientSecret = youtubeSettings?['client_secret']?.toString() ?? '';
    if (clientId.isEmpty || clientSecret.isEmpty) {
      _showSnack('Set YouTube client ID/secret in Settings before fetching per-channel refresh tokens.');
      return;
    }
    final channelLabel = channel['title']?.toString().isNotEmpty == true
        ? channel['title'].toString()
        : channel['channel_id']?.toString() ?? 'channel';
    final redirectUri = 'http://localhost:8080/oauth2callback';
    final scopes = [
      'https://www.googleapis.com/auth/youtube',
      'https://www.googleapis.com/auth/youtube.upload',
      'https://www.googleapis.com/auth/youtube.force-ssl',
    ].map(Uri.encodeComponent).join('%20');
    final authUrl = 'https://accounts.google.com/o/oauth2/v2/auth?'
        'client_id=$clientId&redirect_uri=${Uri.encodeComponent(redirectUri)}&response_type=code'
        '&scope=$scopes&access_type=offline&prompt=consent&include_granted_scopes=true';
    _showSnack('Authorize "$channelLabel" in browser, then paste the code.');
    _launchUrl(authUrl);
    if (!mounted) return;
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OAuthCodeDialog(),
    );
    if (code == null || code.isEmpty) return;
    final tokenPayload = await _exchangeCodeForToken(clientId, clientSecret, code, redirectUri);
    if (tokenPayload == null) return;
    final project = state.activeProject;
    final channelId = channel['channel_id']?.toString();
    if (project == null || channelId == null || channelId.isEmpty) return;
    final record = _channelOAuthRecord(project, channelId, create: true);
    if (record == null) return;
    final refreshToken = tokenPayload['refresh_token']?.toString() ?? '';
    if (refreshToken.isNotEmpty) {
      record['refresh_token'] = refreshToken;
    }
    final accessToken = tokenPayload['access_token']?.toString() ?? '';
    final expiresIn = int.tryParse(tokenPayload['expires_in']?.toString() ?? '') ??
        _defaultYouTubeAccessTokenLifetimeSeconds;
    final now = DateTime.now().toUtc();
    record['access_token'] = accessToken;
    record['access_token_obtained_at'] = now.toIso8601String();
    record['access_token_expires_in_seconds'] = expiresIn;
    record['access_token_expires_at'] = now.add(Duration(seconds: expiresIn)).toIso8601String();
    record['scope'] = tokenPayload['scope']?.toString() ?? '';
    record['token_type'] = tokenPayload['token_type']?.toString() ?? 'Bearer';
    record['last_refresh_at'] = now.toIso8601String();
    record['status'] = 'connected';
    record['last_error'] = '';
    channel['yt_oauth_status'] = 'connected';
    channel['yt_oauth_updated_at'] = now.toIso8601String();
    state.touch();
    _scheduleAutosave(state);
    _showSnack('✅ Saved refresh token + access token for $channelId');
  }

  void _launchUrl(String urlString) {
    unawaited(_launchUrlAsync(urlString));
  }

  Future<void> _launchUrlAsync(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Could not launch $urlString');
      }
    } catch (e) {
      _showSnack('Error opening link: $e');
    }
  }

  void _startOAuthFlow(AppState state) async {
    final youtubeSettings = state.settings['youtube'] as Map?;
    final clientId = youtubeSettings?['client_id'] as String?;
    final clientSecret = youtubeSettings?['client_secret'] as String?;

    if ((clientId == null || clientId.isEmpty) || (clientSecret == null || clientSecret.isEmpty)) {
      _showSnack('Client ID and Client Secret must be set in Settings first.');
      return;
    }

    // Step 1: Direct user to authorization with FULL scopes for all channels
    final redirectUri = 'http://localhost:8080/oauth2callback';
    
    // Use multiple scopes for full channel access including brand accounts
    final scopes = [
      'https://www.googleapis.com/auth/youtube',  // Full YouTube access (not just readonly)
      'https://www.googleapis.com/auth/youtube.force-ssl',  // Force SSL
      'https://www.googleapis.com/auth/yt-analytics.readonly',  // Analytics
      'https://www.googleapis.com/auth/yt-analytics-monetary.readonly',  // Monetary analytics
    ].map((s) => Uri.encodeComponent(s)).join('%20');
    
    final authUrl = 'https://accounts.google.com/o/oauth2/v2/auth?'
        'client_id=$clientId&'
        'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
        'response_type=code&'
        'scope=$scopes&'
        'access_type=offline&'
        'prompt=consent';  // Force consent screen to show all permissions

    _showSnack('Opening Google authorization in browser...\n✓ Grant ALL permissions to access all your channels and brand accounts');
    _launchUrl(authUrl);

    // Step 2: Show dialog to enter the authorization code
    if (!mounted) return;
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OAuthCodeDialog(),
    );

    if (code == null || code.isEmpty) {
      _showSnack('OAuth setup cancelled.');
      return;
    }

    // Step 3: Exchange code for token
    _showSnack('Exchanging authorization code for access token...');
    final tokenPayload = await _exchangeCodeForToken(clientId, clientSecret, code, redirectUri);
    
    final token = tokenPayload?['access_token']?.toString() ?? '';
    if (token.isEmpty) {
      return;
    }

    // Step 4: Auto-save to settings and clipboard
    final youtubeSettings2 = (state.settings['youtube'] as Map?) ?? {};
    youtubeSettings2['oauth_token'] = token;
    state.settings['youtube'] = youtubeSettings2;
    await state.saveSettings(state.settings);

    // Copy to clipboard as well
    await Clipboard.setData(ClipboardData(text: token));
    _showSnack('✅ OAuth token obtained and automatically saved to Settings!\n✅ Token also copied to clipboard for backup.');
  }

  Future<Map<String, dynamic>?> _exchangeCodeForToken(String clientId, String clientSecret, String code, String redirectUri) async {
    try {
      final url = Uri.parse('https://oauth2.googleapis.com/token');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final accessToken = data['access_token'] as String?;
        
        if (accessToken != null && accessToken.isNotEmpty) {
          _showSnack('✅ OAuth token obtained successfully!');
          return data;
        }
      }

      final errorData = jsonDecode(response.body) as Map<String, dynamic>?;
      final errorDesc = errorData?['error_description'] as String? ?? 'Unknown error';
      _showSnack('Error exchanging code: $errorDesc');
      return null;
    } catch (e) {
      _showSnack('Error exchanging code: $e');
      return null;
    }
  }

  void _deleteChannel(AppState state, int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Channel'),
        content: const Text('Are you sure you want to delete this channel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final project = state.activeProject;
              if (project != null) {
                final channels = (project['channels'] as List?)?.cast<Map>() ?? [];
                if (index >= 0 && index < channels.length) {
                  channels.removeAt(index);
                  project['channels'] = channels;
                  state.touch();
                  _scheduleAutosave(state);
                  Navigator.pop(context);
                  _showSnack('Channel deleted.');
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateSongsForAllChannels(AppState state, Map<String, dynamic> project) async {
    final projectName = state.selectedProject;
    if (projectName == null) {
      _showSnack('No project selected');
      return;
    }

    final channels = (project['channels'] as List?)?.cast<Map>() ?? [];
    final enabled = channels.where((ch) => ch['enabled'] ?? true).toList();
    
    if (enabled.isEmpty) {
      _showSnack('No enabled channels found.');
      return;
    }

    _showSnack('Starting song generation for ${enabled.length} channel(s)...');
    
    try {
      final result = await state.api.generateSongs(projectName);
      _showSnack('Song generation completed: $result');
      state.lastWorkflowReport = result;
      state.notifyListeners();
    } catch (e) {
      _showSnack('Song generation failed: $e');
    }
  }

  Future<void> _generateSongsForLanguages(AppState state, Map<String, dynamic> project, List<String> languages) async {
    if (languages.isEmpty) {
      _showSnack('No languages available.');
      return;
    }

    final projectName = state.selectedProject;
    if (projectName == null) {
      _showSnack('No project selected');
      return;
    }

    // Show dialog to select languages
    showDialog(
      context: context,
      builder: (_) {
        final selected = <String>{};
        return StatefulBuilder(
          builder: (_, setState) => AlertDialog(
            title: const Text('Generate by Language'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: languages
                  .map((lang) => CheckboxListTile(
                    title: Text(lang),
                    value: selected.contains(lang),
                    onChanged: (v) {
                      setState(() {
                        if (v ?? false) {
                          selected.add(lang);
                        } else {
                          selected.remove(lang);
                        }
                      });
                    },
                  ))
                  .toList(),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () async {
                      Navigator.pop(context);
                      _showSnack('Generating songs for ${selected.length} language(s)...');
                      try {
                        final result = await state.api.generateSongs(projectName);
                        _showSnack('Song generation completed');
                        state.lastWorkflowReport = result;
                        state.notifyListeners();
                      } catch (e) {
                        _showSnack('Song generation failed: $e');
                      }
                    },
                child: const Text('Generate'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _storyboardPage(AppState state) {
    final project = state.activeProject;
    if (project == null) return const Center(child: Text('Load a project first.'));
    final storyboard = (project['storyboard'] as Map<String, dynamic>? ?? {'globalMood': '', 'scenes': []});
    project['storyboard'] = storyboard;
    final scenes = (storyboard['scenes'] as List?)?.cast<Map>() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: storyboard['globalMood']?.toString() ?? '',
          decoration: const InputDecoration(labelText: 'Global mood'),
          onChanged: (v) => storyboard['globalMood'] = v,
        ),
        const SizedBox(height: 8),
        ...scenes.asMap().entries.map((e) {
          final i = e.key;
          final scene = e.value.cast<String, dynamic>();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scene ${i + 1}', style: Theme.of(context).textTheme.titleMedium),
                  TextFormField(
                    initialValue: scene['text']?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'Text'),
                    onChanged: (v) => scene['text'] = v,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _charactersPage(AppState state) {
    final project = state.activeProject;
    if (project == null) return const Center(child: Text('Load a project first.'));
    final characters = (project['characters'] as List?)?.cast<Map>() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...characters.map((raw) {
          final c = raw.cast<String, dynamic>();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextFormField(
                initialValue: c['name']?.toString(),
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (v) => c['name'] = v,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _generationPage(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Active project: ${state.selectedProject ?? 'None'}'),
        Text('Episode/Generation slot: ${state.selectedEpisodeIndex + 1}'),
        if (state.lastWorkflowReport != null) SelectableText(const JsonEncoder.withIndent('  ').convert(state.lastWorkflowReport)),
      ],
    );
  }

  Widget _previewPage(AppState state) {
    final project = state.activeProject;
    final channelCount = ((project?['channels'] as List?) ?? []).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Channels configured: $channelCount'),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('Preview pane lists generated scene image/video paths once workflow runs.'),
          ),
        ),
      ],
    );
  }

  Widget _uploadPage(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Batch upload placeholders are ready in backend upload service.'),
        ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('YouTube upload pipeline'),
        ),
        ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('TikTok upload pipeline'),
        ),
      ],
    );
  }

  Widget _metricCard(String title, String value) {
    return SizedBox(
      width: 145,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _OAuthCodeDialog extends StatefulWidget {
  @override
  State<_OAuthCodeDialog> createState() => _OAuthCodeDialogState();
}

class _OAuthCodeDialogState extends State<_OAuthCodeDialog> {
  late final TextEditingController codeController;

  @override
  void initState() {
    super.initState();
    codeController = TextEditingController();
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Authorization Code'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✓ IMPORTANT: In the browser, GRANT ALL PERMISSIONS when asked.\n'
              '✓ This enables access to all your channels and brand accounts.\n\n'
              'After you approve access, you will be redirected to a URL:\n'
              'http://localhost:8080/oauth2callback?code=4/0AY0e-...\n\n'
              'Copy the authorization code (the long string after "code=") and paste it below:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: 'Authorization code',
                border: const OutlineInputBorder(),
                hintText: '4/0AY0e-...',
                suffixIcon: codeController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => codeController.clear(),
                      )
                    : null,
              ),
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: codeController.text.isEmpty
              ? null
              : () => Navigator.pop(context, codeController.text.trim()),
          child: const Text('Exchange Code'),
        ),
      ],
    );
  }
}
