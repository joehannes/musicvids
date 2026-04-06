import 'package:flutter/material.dart';

import '../state/app_state.dart';

class SettingsDialog extends StatefulWidget {
  final Map<String, dynamic> initial;
  const SettingsDialog({super.key, required this.initial});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController sunoToken;
  late final TextEditingController midjourneyToken;
  late final TextEditingController youtubeKey;
  late final TextEditingController tiktokUser;
  late final TextEditingController tiktokPass;
  late final TextEditingController openaiKey;
  late String selectedThemeId;

  late final Map<String, TextEditingController> shortcutControllers;
  final List<TextEditingController> customSequenceControllers = [];
  final List<TextEditingController> customLabelControllers = [];

  @override
  void initState() {
    super.initState();
    sunoToken = TextEditingController(text: widget.initial['suno']?['token'] ?? '');
    midjourneyToken = TextEditingController(text: widget.initial['midjourney']?['discord_token'] ?? '');
    youtubeKey = TextEditingController(text: widget.initial['youtube']?['api_key'] ?? '');
    tiktokUser = TextEditingController(text: widget.initial['tiktok']?['username'] ?? '');
    tiktokPass = TextEditingController(text: widget.initial['tiktok']?['password'] ?? '');
    openaiKey = TextEditingController(text: widget.initial['openai']?['api_key'] ?? '');
    selectedThemeId = ((widget.initial['ui'] as Map?)?['theme']?['active']?.toString() ?? 'midnight_focus');

    final existing = ((widget.initial['ui'] as Map?)?['shortcuts'] as Map?)?.cast<String, dynamic>() ?? {};
    shortcutControllers = {
      for (final entry in AppState.defaultShortcutBindings.entries)
        entry.key: TextEditingController(text: existing[entry.key]?.toString() ?? entry.value),
    };
    final customShortcuts = ((widget.initial['ui'] as Map?)?['custom_shortcuts'] as List?)?.whereType<Map>().toList() ?? [];
    for (final item in customShortcuts) {
      customSequenceControllers.add(TextEditingController(text: item['sequence']?.toString() ?? ''));
      customLabelControllers.add(TextEditingController(text: item['label']?.toString() ?? ''));
    }
  }

  @override
  void dispose() {
    sunoToken.dispose();
    midjourneyToken.dispose();
    youtubeKey.dispose();
    tiktokUser.dispose();
    tiktokPass.dispose();
    openaiKey.dispose();
    for (final controller in shortcutControllers.values) {
      controller.dispose();
    }
    for (final controller in customSequenceControllers) {
      controller.dispose();
    }
    for (final controller in customLabelControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings & Mnemonic Shortcuts'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Integrations', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(controller: sunoToken, decoration: const InputDecoration(labelText: 'Suno Token')),
              TextField(controller: midjourneyToken, decoration: const InputDecoration(labelText: 'Midjourney Discord Token')),
              TextField(controller: youtubeKey, decoration: const InputDecoration(labelText: 'YouTube API Key')),
              TextField(controller: tiktokUser, decoration: const InputDecoration(labelText: 'TikTok Username')),
              TextField(controller: tiktokPass, decoration: const InputDecoration(labelText: 'TikTok Password'), obscureText: true),
              TextField(controller: openaiKey, decoration: const InputDecoration(labelText: 'OpenAI API Key (optional)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedThemeId,
                items: const [
                  DropdownMenuItem(value: 'midnight_focus', child: Text('Midnight Focus (Dark)')),
                  DropdownMenuItem(value: 'aurora_light', child: Text('Aurora Light (Light)')),
                  DropdownMenuItem(value: 'contrast_slate', child: Text('Contrast Slate (Dark)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedThemeId = value;
                    });
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Theme',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Shortcut bindings', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Use space-separated mnemonic letters (example: "p s" for Project > Save).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ...shortcutControllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: entry.key,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Custom shortcuts', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        customSequenceControllers.add(TextEditingController());
                        customLabelControllers.add(TextEditingController());
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...List.generate(customSequenceControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: customSequenceControllers[index],
                          decoration: const InputDecoration(
                            labelText: 'Sequence',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: customLabelControllers[index],
                          decoration: const InputDecoration(
                            labelText: 'Meaning',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'suno': {'token': sunoToken.text},
              'midjourney': {'discord_token': midjourneyToken.text},
              'youtube': {'api_key': youtubeKey.text, 'channel_ids': []},
              'tiktok': {'username': tiktokUser.text, 'password': tiktokPass.text},
              'openai': {'api_key': openaiKey.text},
              'ui': {
                'shortcuts': {
                  for (final shortcut in shortcutControllers.entries) shortcut.key: shortcut.value.text.trim(),
                },
                'custom_shortcuts': List.generate(customSequenceControllers.length, (index) {
                  return {
                    'sequence': customSequenceControllers[index].text.trim(),
                    'label': customLabelControllers[index].text.trim(),
                  };
                }).where((entry) => (entry['sequence'] ?? '').isNotEmpty && (entry['label'] ?? '').isNotEmpty).toList(),
                'theme': {'active': selectedThemeId},
              },
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
