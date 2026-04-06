import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/list_popup.dart';
import '../widgets/settings_dialog.dart';

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
    _newProjectController.dispose();
    _keyboardFocus.dispose();
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
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _openSettings(state),
        tooltip: 'Settings (s o)',
        shape: const CircleBorder(),
        child: const Icon(Icons.settings),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: SafeArea(
        child: Focus(
          autofocus: true,
          focusNode: _keyboardFocus,
          child: Stack(
            children: [
              _buildCanvas(state),
              if (_mnemonicMode) _buildMnemonicGuide(state),
              if (state.loading)
                const Positioned(
                  top: 8,
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

  KeyEventResult _onKeyEvent(AppState state, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final keyLabel = key.keyLabel.toLowerCase();
    final textFieldFocused = _isTextFieldFocused();

    if (!_mnemonicMode && key == LogicalKeyboardKey.space) {
      if (HardwareKeyboard.instance.isMetaPressed || !textFieldFocused) {
        _startMnemonicMode();
        return KeyEventResult.handled;
      }
    }

    if (!_mnemonicMode && !textFieldFocused && ['h', 'j', 'k', 'l'].contains(keyLabel)) {
      _scrollByDirection(keyLabel);
      return KeyEventResult.handled;
    }

    if (_mnemonicMode) {
      if (key == LogicalKeyboardKey.escape) {
        _cancelMnemonic();
        return KeyEventResult.handled;
      }
      if (RegExp(r'^[a-z]$').hasMatch(keyLabel)) {
        _mnemonicSequence = _mnemonicSequence.isEmpty ? keyLabel : '$_mnemonicSequence $keyLabel';
        _mnemonicFailed = false;
        if (_matchesKnownShortcut(_mnemonicSequence, state)) {
          unawaited(_resolveMnemonicSequence(state));
          return KeyEventResult.handled;
        }
        _restartMnemonicTimer(state);
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
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _screenPanOffsets[_activeScreenId] = pan + details.delta;
        });
      },
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
            ),
            Transform.translate(
              offset: pan,
              child: SizedBox(
                width: viewport.width,
                height: viewport.height,
                child: _pageForScreen(_activeScreenId, state),
              ),
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

  Widget _buildMnemonicGuide(AppState state) {
    final available = <Map<String, String>>[];
    final nextLetters = <String>{};

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
        });
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
        });
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
    final capped = available.take(24).toList();

    return Align(
      alignment: Alignment.center,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: 1,
        child: Container(
          width: 860,
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
              Text('Mnemonic Guide', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                _mnemonicSequence.isEmpty ? 'Type a sequence (example: S O)' : 'Sequence: $_mnemonicSequence',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: nextLetters
                    .map((n) => Chip(
                          label: Text(n.toUpperCase()),
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.25),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 360,
                child: ListView(
                  children: capped
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
    _restartMnemonicTimer(context.read<AppState>());
  }

  void _restartMnemonicTimer(AppState state) {
    _mnemonicTimer?.cancel();
    _mnemonicTimer = Timer(const Duration(seconds: 1), () => _resolveMnemonicSequence(state));
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

    await _runAction(action, state);
    if (mounted) {
      _cancelMnemonic();
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
    final context = focused?.context;
    final widget = context?.widget;
    return widget is EditableText;
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
    channels.add({
      'channel_id': 'channel_${channels.length + 1}',
      'language': 'en',
      'title': 'New Channel',
      'description': '',
      'vibe': 'cinematic',
      'visual_style': 'stylized',
      'enabled': true,
    });
    project['channels'] = channels;
    state.touch();
    _showSnack('Channel added.');
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
    final channels = (project?['channels'] as List?) ?? [];
    final scenes = (project?['storyboard']?['scenes'] as List?) ?? [];
    final characters = (project?['characters'] as List?) ?? [];
    return ListView(
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
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: Text('Active project: ${state.selectedProject ?? 'None'}'),
            subtitle: const Text('Navigate through canvas via mnemonic mode (Space → keys) or h/j/k/l scroll'),
          ),
        ),
        if (state.lastWorkflowReport != null) ...[
          const SizedBox(height: 12),
          Text('Last workflow report', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(const JsonEncoder.withIndent('  ').convert(state.lastWorkflowReport)),
        ],
      ],
    );
  }

  Widget _projectsPage(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _newProjectController,
          decoration: const InputDecoration(labelText: 'New project name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(onPressed: () => state.createProject(_newProjectController.text), child: const Text('Create')),
            OutlinedButton(onPressed: state.refreshProjects, child: const Text('Refresh')),
            OutlinedButton(onPressed: state.selectedProject == null ? null : state.saveActiveProject, child: const Text('Save active')),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: state.projects.length,
            itemBuilder: (_, i) {
              final name = state.projects[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(name),
                  subtitle: Text(name == state.selectedProject ? 'Loaded' : 'Click to load'),
                  trailing: OutlinedButton(onPressed: () => state.loadProject(name), child: const Text('Load')),
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

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: currentLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Current language',
                      border: OutlineInputBorder(),
                    ),
                    items: languages
                        .map((lang) => DropdownMenuItem<String>(value: lang, child: Text(lang.toUpperCase())))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      lyrics['current_language'] = value;
                      state.touch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final selected = await showListPopup<String>(
                      context: context,
                      title: 'Manage lyric languages',
                      selectedValue: currentLanguage,
                      helperText: 'Select to switch language (j/k or ↑/↓).',
                      entries: languages
                          .map((lang) => ListPopupEntry<String>(
                                value: lang,
                                label: lang.toUpperCase(),
                                subtitle: lang == currentLanguage ? 'Current language' : 'Switch to this language',
                              ))
                          .toList(),
                    );
                    if (selected != null) {
                      lyrics['current_language'] = selected;
                      state.touch();
                    }
                  },
                  icon: const Icon(Icons.translate),
                  label: const Text('Languages'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final input = TextEditingController();
                    final newLang = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Add language'),
                        content: TextField(
                          controller: input,
                          decoration: const InputDecoration(
                            labelText: 'Language code (e.g. en, es, fr)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(context, input.text.trim().toLowerCase()), child: const Text('Add')),
                        ],
                      ),
                    );
                    if (newLang == null || newLang.isEmpty || languages.contains(newLang)) {
                      return;
                    }
                    languages.add(newLang);
                    for (final block in blocks) {
                      final texts = (block['texts'] as Map).cast<String, dynamic>();
                      texts[newLang] = '';
                    }
                    lyrics['current_language'] = newLang;
                    state.touch();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: languages.length <= 1
                      ? null
                      : () {
                          final removalTarget = currentLanguage;
                          languages.remove(removalTarget);
                          for (final block in blocks) {
                            final texts = (block['texts'] as Map).cast<String, dynamic>();
                            texts.remove(removalTarget);
                          }
                          lyrics['current_language'] = languages.first;
                          state.touch();
                        },
                  icon: const Icon(Icons.remove),
                  label: const Text('Remove current'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _addLyricSection(state),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Add lyrics block'),
            ),
            OutlinedButton.icon(
              onPressed: blocks.isEmpty ? null : () => _deleteLastLyricSection(state),
              icon: const Icon(Icons.indeterminate_check_box_outlined),
              label: const Text('Remove last block'),
            ),
          ],
        ),
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
                      IconButton(
                        onPressed: () {
                          block['muted'] = !muted;
                          state.touch();
                        },
                        tooltip: muted ? 'Unmute block' : 'Mute block',
                        icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
                      ),
                    ],
                  ),
                  TextFormField(
                    key: ValueKey('lyrics-$index-$currentLanguage'),
                    initialValue: texts[currentLanguage]?.toString() ?? '',
                    maxLines: null,
                    minLines: 2,
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
    final channels = (project['channels'] as List?)?.cast<Map>() ?? [];
    return ListView(
      children: [
        Row(
          children: [
            const Spacer(),
            FilledButton.icon(onPressed: () => _addChannel(state), icon: const Icon(Icons.add), label: const Text('Add channel')),
          ],
        ),
        const SizedBox(height: 8),
        ...channels.map((raw) {
          final ch = raw.cast<String, dynamic>();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: ch['channel_id']?.toString(),
                          decoration: const InputDecoration(labelText: 'Channel ID'),
                          onChanged: (v) => ch['channel_id'] = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: ch['language']?.toString(),
                          decoration: const InputDecoration(labelText: 'Language'),
                          onChanged: (v) => ch['language'] = v,
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    initialValue: ch['title']?.toString(),
                    decoration: const InputDecoration(labelText: 'Title'),
                    onChanged: (v) => ch['title'] = v,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _storyboardPage(AppState state) {
    final project = state.activeProject;
    if (project == null) return const Center(child: Text('Load a project first.'));
    final storyboard = (project['storyboard'] as Map<String, dynamic>? ?? {'globalMood': '', 'scenes': []});
    project['storyboard'] = storyboard;
    final scenes = (storyboard['scenes'] as List?)?.cast<Map>() ?? [];
    return ListView(
      children: [
        TextFormField(
          initialValue: storyboard['globalMood']?.toString() ?? '',
          decoration: const InputDecoration(labelText: 'Global mood'),
          onChanged: (v) => storyboard['globalMood'] = v,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: () => _addScene(state), icon: const Icon(Icons.add), label: const Text('Add scene')),
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
    return ListView(
      children: [
        FilledButton.icon(onPressed: () => _addCharacter(state), icon: const Icon(Icons.add), label: const Text('Add character')),
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
    return ListView(
      children: [
        Text('Active project: ${state.selectedProject ?? 'None'}'),
        Text('Episode/Generation slot: ${state.selectedEpisodeIndex + 1}'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: state.selectedProject == null ? null : state.runWorkflow,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run Full Workflow'),
            ),
            OutlinedButton(onPressed: state.nextEpisode, child: const Text('Next episode')),
            OutlinedButton(onPressed: state.previousEpisode, child: const Text('Previous episode')),
          ],
        ),
        if (state.lastWorkflowReport != null) SelectableText(const JsonEncoder.withIndent('  ').convert(state.lastWorkflowReport)),
      ],
    );
  }

  Widget _previewPage(AppState state) {
    final project = state.activeProject;
    final channelCount = ((project?['channels'] as List?) ?? []).length;
    return ListView(
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
    return const ListView(
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
