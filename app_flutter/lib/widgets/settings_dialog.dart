import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    sunoToken = TextEditingController(text: widget.initial['suno']?['token'] ?? '');
    midjourneyToken = TextEditingController(text: widget.initial['midjourney']?['discord_token'] ?? '');
    youtubeKey = TextEditingController(text: widget.initial['youtube']?['api_key'] ?? '');
    tiktokUser = TextEditingController(text: widget.initial['tiktok']?['username'] ?? '');
    tiktokPass = TextEditingController(text: widget.initial['tiktok']?['password'] ?? '');
    openaiKey = TextEditingController(text: widget.initial['openai']?['api_key'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: sunoToken, decoration: const InputDecoration(labelText: 'Suno Token')),
            TextField(controller: midjourneyToken, decoration: const InputDecoration(labelText: 'Midjourney Discord Token')),
            TextField(controller: youtubeKey, decoration: const InputDecoration(labelText: 'YouTube API Key')),
            TextField(controller: tiktokUser, decoration: const InputDecoration(labelText: 'TikTok Username')),
            TextField(controller: tiktokPass, decoration: const InputDecoration(labelText: 'TikTok Password'), obscureText: true),
            TextField(controller: openaiKey, decoration: const InputDecoration(labelText: 'OpenAI API Key (optional)')),
          ],
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
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
