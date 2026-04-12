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
  late final TextEditingController youtubeClientId;
  late final TextEditingController youtubeClientSecret;
  late final TextEditingController youtubeOAuthToken;
  late final TextEditingController youtubeEmail;
  late final TextEditingController youtubeHandle;
  late final TextEditingController youtubeBrandChannelId;
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
    youtubeClientId = TextEditingController(text: widget.initial['youtube']?['client_id'] ?? '');
    youtubeClientSecret = TextEditingController(text: widget.initial['youtube']?['client_secret'] ?? '');
    youtubeOAuthToken = TextEditingController(text: widget.initial['youtube']?['oauth_token'] ?? '');
    youtubeEmail = TextEditingController(text: widget.initial['youtube']?['account_email'] ?? '');
    youtubeHandle = TextEditingController(text: widget.initial['youtube']?['account_handle'] ?? '');
    youtubeBrandChannelId = TextEditingController(text: widget.initial['youtube']?['brand_channel_id'] ?? '');
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
    youtubeClientId.dispose();
    youtubeClientSecret.dispose();
    youtubeOAuthToken.dispose();
    youtubeEmail.dispose();
    youtubeHandle.dispose();
    youtubeBrandChannelId.dispose();
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Fixed Top Taskbar', style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '✓ Fixed taskbar at top of screen\n'
                      '✓ Screen navigation (left) - Click icons to switch screens\n'
                      '✓ Screen-specific actions (center/right) - Context-aware tools\n'
                      '✓ Small, organized icon buttons\n'
                      '✓ Stays in place while canvas pans/scrolls\n'
                      '\n'
                      'Each screen has custom actions:\n'
                      '• Dashboard: Create, Save, Refresh\n'
                      '• Channels: Sync, Add, Test, Export/Import\n'
                      '• Lyrics: Add/Delete sections, Navigate chapters\n'
                      '• Storyboard: Manage scenes\n'
                      '• Characters: Add/Manage characters\n'
                      '• Generation: Run workflow, Episodes\n'
                      '• Upload: Video upload controls',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.touch_app, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Touch Shortcuts Guide (Mobile)', style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'For keyboard-less and mobile devices:\n'
                      '\n'
                      '✓ Floating guide in top-right corner\n'
                      '✓ Shows shortcut categories on tap\n'
                      '✓ Drill down to specific actions\n'
                      '✓ Back button to return to categories\n'
                      '✓ Compact, fully-rounded icon buttons\n'
                      '✓ Meaningful icons (Font Awesome)\n'
                      '✓ Auto-closes after action or tap outside\n'
                      '\n'
                      'Categories: Navigation, Project, Channel, Lyrics,\n'
                      'Storyboard, Character, Generation, Settings, Custom',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('YouTube Channel Workflow', style: Theme.of(context).textTheme.labelMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Set YouTube Client ID + Client Secret\n'
                      '2. Add channels using:\n'
                      '   • "Add Manual" for single channel IDs\n'
                      '   • "Generate Pattern" for batch creation (e.g., "UC" + "abc" + "01...50")\n'
                      '3. On each channel card, click "Fetch refresh token"\n'
                      '4. Click "Sync All" to fetch metadata for all channels\n'
                      '5. Data auto-saves every 500ms\n'
                      '\n'
                      'Tip: Find channel ID in youtube.com/channel/UC...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('YouTube Account', style: Theme.of(context).textTheme.titleSmall),
              TextField(controller: youtubeKey, decoration: const InputDecoration(labelText: 'YouTube API Key')),
              TextField(
                controller: youtubeClientId,
                decoration: const InputDecoration(
                  labelText: 'YouTube Client ID',
                  helperText: 'From Google Console: Create OAuth 2.0 Client ID (Desktop app)',
                ),
              ),
              TextField(
                controller: youtubeClientSecret,
                decoration: const InputDecoration(
                  labelText: 'YouTube Client Secret',
                  helperText: 'From Google Console: Found with Client ID in credentials JSON',
                ),
              ),
              TextField(
                controller: youtubeOAuthToken,
                decoration: InputDecoration(
                  labelText: 'Legacy global OAuth access token (optional)',
                  helperText: 'Deprecated fallback only. Preferred flow is per-channel refresh token.',
                ),
                maxLines: 2,
              ),
              TextField(controller: youtubeEmail, decoration: const InputDecoration(labelText: 'Google Account Email')),
              TextField(controller: youtubeHandle, decoration: const InputDecoration(labelText: 'YouTube Channel Handle (@username)')),
              TextField(controller: youtubeBrandChannelId, decoration: const InputDecoration(labelText: 'Brand Account Channel ID')),
              const SizedBox(height: 12),
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
              'youtube': {
                'api_key': youtubeKey.text,
                'client_id': youtubeClientId.text,
                'client_secret': youtubeClientSecret.text,
                'oauth_token': youtubeOAuthToken.text,
                'account_email': youtubeEmail.text,
                'account_handle': youtubeHandle.text,
                'brand_channel_id': youtubeBrandChannelId.text,
                'channel_ids': []
              },
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
