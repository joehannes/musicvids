import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
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

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _newProjectController = TextEditingController();
  final FocusNode _keyboardFocus = FocusNode();
  final ScrollController _horizontalController = ScrollController(initialScrollOffset: 3000);
  final ScrollController _verticalController = ScrollController(initialScrollOffset: 3000);

  final double _screenCardWidth = 520;
  final double _screenCardHeight = 420;
  final double _screenSpacing = 620;

  final List<_CanvasScreen> _screens = const [
    _CanvasScreen(id: 'dashboard', label: 'Dashboard', icon: Icons.dashboard, offset: Offset(0, 0)),
    _CanvasScreen(id: 'projects', label: 'Projects', icon: Icons.folder, offset: Offset(-1, 0)),
    _CanvasScreen(id: 'lyrics', label: 'Lyrics', icon: Icons.library_music, offset: Offset(1, 0)),
    _CanvasScreen(id: 'channels', label: 'Channels', icon: Icons.people, offset: Offset(0, 1)),
    _CanvasScreen(id: 'storyboard', label: 'Storyboard', icon: Icons.view_timeline, offset: Offset(0, -1)),
    _CanvasScreen(id: 'characters', label: 'Characters', icon: Icons.person, offset: Offset(1, 1)),
    _CanvasScreen(id: 'generation', label: 'Generation', icon: Icons.movie, offset: Offset(2, 0)),
    _CanvasScreen(id: 'preview', label: 'Preview', icon: Icons.preview, offset: Offset(2, 1)),
    _CanvasScreen(id: 'upload', label: 'Upload', icon: Icons.upload, offset: Offset(2, 2)),
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
      _scrollToActiveScreen();
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
    _horizontalController.dispose();
    _verticalController.dispose();
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
      appBar: AppBar(
        title: const Text('MusicVid Studio — Infinite Canvas'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _mnemonicMode
                    ? 'Mnemonic: ${_mnemonicSequence.isEmpty ? '…' : _mnemonicSequence}'
                    : 'Press Super+Space (or Space with no text field)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSettings(state),
        tooltip: 'Settings (s o)',
        child: const Icon(Icons.settings),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: Focus(
        autofocus: true,
        focusNode: _keyboardFocus,
        onKeyEvent: (node, event) => _onKeyEvent(state, event),
        child: Stack(
          children: [
            _buildCanvas(state),
            if (_mnemonicMode) _buildMnemonicGuide(state),
            if (state.loading) const Positioned.fill(child: Center(child: CircularProgressIndicator())),
          ],
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
        _restartMnemonicTimer(state);
        setState(() {});
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Widget _buildCanvas(AppState state) {
    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 6000,
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            notificationPredicate: (_) => true,
            child: SingleChildScrollView(
              controller: _verticalController,
              child: SizedBox(
                width: 6000,
                height: 6000,
                child: Stack(
                  children: _screens.map((screen) {
                    final left = 3000 + (screen.offset.dx * _screenSpacing) - (_screenCardWidth / 2);
                    final top = 3000 + (screen.offset.dy * _screenSpacing) - (_screenCardHeight / 2);
                    final active = screen.id == _activeScreenId;
                    return Positioned(
                      left: left,
                      top: top,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: _screenCardWidth,
                        height: _screenCardHeight,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active ? Theme.of(context).colorScheme.primary : Colors.white24,
                            width: active ? 2.5 : 1.0,
                          ),
                          color: active ? Colors.white.withOpacity(0.06) : Colors.black26,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(screen.icon),
                                const SizedBox(width: 8),
                                Text(screen.label, style: Theme.of(context).textTheme.titleLarge),
                                const Spacer(),
                                if (active)
                                  const Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text('Active'),
                                  ),
                              ],
                            ),
                            const Divider(),
                            Expanded(child: _pageForScreen(screen.id, state)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMnemonicGuide(AppState state) {
    final shortcuts = state.shortcutBindings;
    final available = <String, String>{};
    final nextLetters = <String>{};

    for (final entry in shortcuts.entries) {
      final sequence = entry.value.trim();
      if (sequence.isEmpty) continue;
      final tokens = sequence.split(RegExp(r'\s+'));
      if (_mnemonicSequence.isEmpty) {
        nextLetters.add(tokens.first);
      } else if (sequence.startsWith(_mnemonicSequence)) {
        available[entry.key] = sequence;
        final currentTokens = _mnemonicSequence.split(' ');
        if (tokens.length > currentTokens.length) {
          nextLetters.add(tokens[currentTokens.length]);
        }
      }
    }

    return Positioned(
      top: 16,
      right: 16,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: 1,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _mnemonicFailed ? Colors.red.withOpacity(0.35) : Colors.black.withOpacity(0.8),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Mnemonic Guide', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                _mnemonicSequence.isEmpty ? 'Start typing category letters…' : 'Sequence: $_mnemonicSequence',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: nextLetters.map((n) => Chip(label: Text(n.toUpperCase()))).toList(),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 180,
                child: ListView(
                  children: available.entries
                      .map((e) => ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text(e.key),
                            trailing: Text(e.value.toUpperCase()),
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
        _moveScreen(0, -1);
        break;
      case 'navigate.down':
        _moveScreen(0, 1);
        break;
      case 'project.new':
        await _showQuickCreateProjectDialog(state);
        break;
      case 'project.open':
        if (state.projects.isNotEmpty) {
          await state.loadProject(state.projects.first);
        }
        _showSnack('Opened first project in list.');
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
        _addLyricSection(state);
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
      _horizontalController.animateTo(
        (_horizontalController.offset - deltaX).clamp(0, _horizontalController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else if (direction == 'l') {
      _horizontalController.animateTo(
        (_horizontalController.offset + deltaX).clamp(0, _horizontalController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else if (direction == 'k') {
      _verticalController.animateTo(
        (_verticalController.offset - deltaY).clamp(0, _verticalController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } else if (direction == 'j') {
      _verticalController.animateTo(
        (_verticalController.offset + deltaY).clamp(0, _verticalController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _moveScreen(int dx, int dy) {
    final current = _screens.firstWhere((s) => s.id == _activeScreenId);
    final sameAxisCandidates = _screens.where((candidate) {
      if (dx != 0) {
        return candidate.offset.dy == current.offset.dy;
      }
      return candidate.offset.dx == current.offset.dx;
    }).toList();

    _CanvasScreen? target;
    if (dx > 0) {
      final right = sameAxisCandidates.where((c) => c.offset.dx > current.offset.dx).toList();
      target = right.isNotEmpty
          ? right.reduce((a, b) => a.offset.dx < b.offset.dx ? a : b)
          : sameAxisCandidates.reduce((a, b) => a.offset.dx > b.offset.dx ? a : b);
    } else if (dx < 0) {
      final left = sameAxisCandidates.where((c) => c.offset.dx < current.offset.dx).toList();
      target = left.isNotEmpty
          ? left.reduce((a, b) => a.offset.dx > b.offset.dx ? a : b)
          : sameAxisCandidates.reduce((a, b) => a.offset.dx < b.offset.dx ? a : b);
    } else if (dy > 0) {
      final down = sameAxisCandidates.where((c) => c.offset.dy > current.offset.dy).toList();
      target = down.isNotEmpty
          ? down.reduce((a, b) => a.offset.dy < b.offset.dy ? a : b)
          : sameAxisCandidates.reduce((a, b) => a.offset.dy > b.offset.dy ? a : b);
    } else {
      final up = sameAxisCandidates.where((c) => c.offset.dy < current.offset.dy).toList();
      target = up.isNotEmpty
          ? up.reduce((a, b) => a.offset.dy > b.offset.dy ? a : b)
          : sameAxisCandidates.reduce((a, b) => a.offset.dy < b.offset.dy ? a : b);
    }

    setState(() {
      _activeScreenId = (target ?? current).id;
    });
    _scrollToActiveScreen();
  }

  void _scrollToActiveScreen() {
    if (!_horizontalController.hasClients || !_verticalController.hasClients) {
      return;
    }
    final current = _screens.firstWhere((s) => s.id == _activeScreenId);
    final viewport = MediaQuery.sizeOf(context);
    final targetX = 3000 + (current.offset.dx * _screenSpacing) - viewport.width / 2;
    final targetY = 3000 + (current.offset.dy * _screenSpacing) - viewport.height / 2;
    _horizontalController.animateTo(
      targetX.clamp(0, _horizontalController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
    _verticalController.animateTo(
      targetY.clamp(0, _verticalController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
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

  void _addLyricSection(AppState state) {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }
    final lyrics = (project['lyrics'] as Map<String, dynamic>? ?? {});
    final en = (lyrics['en'] as Map<String, dynamic>? ?? {'enabled': true, 'sections': <String>[], 'tone_notes': ''});
    final sections = (en['sections'] as List?)?.cast<String>() ?? <String>[];
    sections.add('New lyric section...');
    en['sections'] = sections;
    lyrics['en'] = en;
    project['lyrics'] = lyrics;
    state.touch();
    _showSnack('Lyric section added.');
  }

  void _deleteLastLyricSection(AppState state) {
    final project = state.activeProject;
    if (project == null) return;
    final lyrics = (project['lyrics'] as Map<String, dynamic>? ?? {});
    final en = (lyrics['en'] as Map<String, dynamic>? ?? {});
    final sections = (en['sections'] as List?)?.cast<String>() ?? <String>[];
    if (sections.isNotEmpty) {
      sections.removeLast();
      en['sections'] = sections;
      lyrics['en'] = en;
      state.touch();
      _showSnack('Removed last lyric section.');
    }
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.primary),
          ),
          child: const Text(
            'INFINITE CANVAS MODE ACTIVE — Trigger mnemonics with Super+Space (or Space when no input is focused).',
          ),
        ),
        const SizedBox(height: 12),
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
    final lyrics = (project['lyrics'] as Map<String, dynamic>? ?? {});
    if (lyrics.isEmpty) {
      lyrics['en'] = {'enabled': true, 'sections': [''], 'tone_notes': ''};
    }
    return ListView(
      children: [
        ...lyrics.entries.map((entry) {
          final lang = entry.key;
          final value = entry.value as Map<String, dynamic>;
          final sections = (value['sections'] as List?)?.cast<String>() ?? [''];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Language: $lang', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Switch(
                        value: value['enabled'] == true,
                        onChanged: (v) {
                          value['enabled'] = v;
                          state.touch();
                        },
                      ),
                    ],
                  ),
                  ...sections.asMap().entries.map((s) => TextFormField(
                        initialValue: s.value,
                        maxLines: 2,
                        decoration: InputDecoration(labelText: 'Section ${s.key + 1}'),
                        onChanged: (v) => sections[s.key] = v,
                      )),
                  TextFormField(
                    initialValue: value['tone_notes']?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'Tone/style notes'),
                    onChanged: (v) => value['tone_notes'] = v,
                  ),
                ],
              ),
            ),
          );
        }),
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
    return ListView(
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
