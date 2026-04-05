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
        title: const Text('MusicVid Studio Dashboard'),
        actions: [
          IconButton(
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
            selectedIndex: 0,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.folder), label: Text('Projects')),
              NavigationRailDestination(icon: Icon(Icons.library_music), label: Text('Lyrics')),
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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Projects (${state.projects.length})', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: state.projects.length,
                            itemBuilder: (_, i) => ListTile(
                              leading: const Icon(Icons.folder_open),
                              title: Text(state.projects[i]),
                            ),
                          ),
                        ),
                        const Divider(),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(onPressed: () {}, child: const Text('Run All')),
                            OutlinedButton(onPressed: () {}, child: const Text('Run Partial')),
                            OutlinedButton(onPressed: () {}, child: const Text('Resume Incomplete')),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
