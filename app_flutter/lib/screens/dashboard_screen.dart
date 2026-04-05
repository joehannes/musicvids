import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/settings_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _newProjectController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('MusicVid Studio'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => state.bootstrap(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Save project',
            onPressed: state.activeProject == null ? null : state.saveActiveProject,
            icon: const Icon(Icons.save),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              final updated = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (_) => SettingsDialog(initial: state.settings),
              );
              if (updated != null) {
                await state.saveSettings(updated);
              }
            },
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: state.selectedNavIndex,
            onDestinationSelected: state.setNav,
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.folder), label: Text('Projects')),
              NavigationRailDestination(icon: Icon(Icons.library_music), label: Text('Lyrics')),
              NavigationRailDestination(icon: Icon(Icons.people), label: Text('Channels')),
              NavigationRailDestination(icon: Icon(Icons.view_timeline), label: Text('Storyboard')),
              NavigationRailDestination(icon: Icon(Icons.person), label: Text('Characters')),
              NavigationRailDestination(icon: Icon(Icons.movie), label: Text('Generation')),
              NavigationRailDestination(icon: Icon(Icons.preview), label: Text('Video Preview')),
              NavigationRailDestination(icon: Icon(Icons.upload), label: Text('Upload')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildPage(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(AppState state) {
    if (state.error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            color: Colors.red.withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(state.error!),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => state.bootstrap(),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Retry connection'),
          ),
        ],
      );
    }

    switch (state.selectedNavIndex) {
      case 0:
        return _dashboardPage(state);
      case 1:
        return _projectsPage(state);
      case 2:
        return _lyricsPage(state);
      case 3:
        return _channelsPage(state);
      case 4:
        return _storyboardPage(state);
      case 5:
        return _charactersPage(state);
      case 6:
        return _generationPage(state);
      case 7:
        return _previewPage(state);
      case 8:
        return _uploadPage(state);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _dashboardPage(AppState state) {
    final project = state.activeProject;
    final channels = (project?['channels'] as List?) ?? [];
    final scenes = (project?['storyboard']?['scenes'] as List?) ?? [];
    final characters = (project?['characters'] as List?) ?? [];
    return ListView(
      children: [
        Text('Workflow Dashboard', style: Theme.of(context).textTheme.headlineSmall),
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
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: ListTile(
            title: Text('Active project: ${state.selectedProject ?? 'None'}'),
            subtitle: const Text('Use Projects tab to create/load. Use Save icon after editing any tab.'),
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
        Text('Projects', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newProjectController,
                decoration: const InputDecoration(labelText: 'New project name', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                await state.createProject(_newProjectController.text);
                _newProjectController.clear();
              },
              child: const Text('Create'),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                  trailing: OutlinedButton(
                    onPressed: () => state.loadProject(name),
                    child: const Text('Load'),
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
    final lyrics = (project['lyrics'] as Map<String, dynamic>? ?? {});
    if (lyrics.isEmpty) {
      lyrics['en'] = {'enabled': true, 'sections': [''], 'tone_notes': ''};
    }
    return ListView(
      children: [
        Text('Lyrics', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
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
            Text('Channels', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {
                channels.add({
                  'channel_id': 'channel_${channels.length + 1}',
                  'language': 'en',
                  'title': 'New Channel',
                  'description': '',
                  'vibe': 'cinematic',
                  'visual_style': 'stylized',
                  'enabled': true,
                });
                state.touch();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add channel'),
            ),
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
                      const SizedBox(width: 8),
                      Switch(
                        value: ch['enabled'] == true,
                        onChanged: (v) {
                          ch['enabled'] = v;
                          state.touch();
                        },
                      ),
                    ],
                  ),
                  TextFormField(
                    initialValue: ch['title']?.toString(),
                    decoration: const InputDecoration(labelText: 'Title'),
                    onChanged: (v) => ch['title'] = v,
                  ),
                  TextFormField(
                    initialValue: ch['description']?.toString(),
                    decoration: const InputDecoration(labelText: 'Description'),
                    onChanged: (v) => ch['description'] = v,
                  ),
                  TextFormField(
                    initialValue: ch['vibe']?.toString(),
                    decoration: const InputDecoration(labelText: 'Music vibe'),
                    onChanged: (v) => ch['vibe'] = v,
                  ),
                  TextFormField(
                    initialValue: ch['visual_style']?.toString(),
                    decoration: const InputDecoration(labelText: 'Visual style'),
                    onChanged: (v) => ch['visual_style'] = v,
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
        Text('Storyboard', style: Theme.of(context).textTheme.headlineSmall),
        TextFormField(
          initialValue: storyboard['globalMood']?.toString() ?? '',
          decoration: const InputDecoration(labelText: 'Global mood'),
          onChanged: (v) => storyboard['globalMood'] = v,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () {
            scenes.add({'text': '', 'imagery': '', 'type': 'single', 'manualStart': null, 'manualEnd': null});
            storyboard['scenes'] = scenes;
            state.touch();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add scene'),
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
                  TextFormField(
                    initialValue: scene['imagery']?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'Imagery'),
                    onChanged: (v) => scene['imagery'] = v,
                  ),
                  TextFormField(
                    initialValue: scene['type']?.toString() ?? 'single',
                    decoration: const InputDecoration(labelText: 'Type (single|pack)'),
                    onChanged: (v) => scene['type'] = v,
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
        Row(
          children: [
            Text('Characters', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            FilledButton.icon(
              onPressed: () {
                characters.add({'name': 'New Character', 'description': '', 'variations': ['default']});
                project['characters'] = characters;
                state.touch();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add character'),
            ),
          ],
        ),
        ...characters.map((raw) {
          final c = raw.cast<String, dynamic>();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: c['name']?.toString(),
                    decoration: const InputDecoration(labelText: 'Name'),
                    onChanged: (v) => c['name'] = v,
                  ),
                  TextFormField(
                    initialValue: c['description']?.toString(),
                    decoration: const InputDecoration(labelText: 'Description'),
                    onChanged: (v) => c['description'] = v,
                  ),
                  TextFormField(
                    initialValue: ((c['variations'] as List?) ?? []).join(', '),
                    decoration: const InputDecoration(labelText: 'Variations (comma-separated)'),
                    onChanged: (v) => c['variations'] = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  ),
                ],
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
        Text('Generation', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Active project: ${state.selectedProject ?? 'None'}'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: state.selectedProject == null ? null : state.runWorkflow,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run Full Workflow'),
            ),
            OutlinedButton(
              onPressed: state.selectedProject == null ? null : state.saveActiveProject,
              child: const Text('Save Project State'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Pipeline order: songs → analyze audio → prompts → images → videos → upload'),
        const SizedBox(height: 8),
        if (state.lastWorkflowReport != null) SelectableText(const JsonEncoder.withIndent('  ').convert(state.lastWorkflowReport)),
      ],
    );
  }

  Widget _previewPage(AppState state) {
    final project = state.activeProject;
    final channelCount = ((project?['channels'] as List?) ?? []).length;
    return ListView(
      children: [
        Text('Video Preview', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Preview pane is project-aware and lists generated scene image/video paths once workflow runs.'),
        const SizedBox(height: 8),
        Text('Channels configured: $channelCount'),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('For low-resource desktop mode, preview uses local files from /projects/<project>/videos and /images. Full media playback wiring can be extended with video_player once renders exist.'),
          ),
        ),
      ],
    );
  }

  Widget _uploadPage(AppState state) {
    return ListView(
      children: [
        Text('Upload', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Batch upload wiring placeholders are ready in backend upload service. Configure credentials in Settings.'),
        const SizedBox(height: 12),
        const ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('YouTube upload pipeline'),
          subtitle: Text('Credential fields persisted locally; batch/retry hooks ready in workflow service.'),
        ),
        const ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('TikTok upload pipeline'),
          subtitle: Text('Credential fields persisted locally; upload adapter can be expanded per API constraints.'),
        ),
      ],
    );
  }

  Widget _metricCard(String title, String value) {
    return SizedBox(
      width: 180,
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
