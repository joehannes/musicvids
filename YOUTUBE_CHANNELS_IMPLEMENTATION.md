# YouTube Channels Widget - Full Implementation Guide

## ✅ Completed

### Flutter Frontend
- **Enhanced channels widget** with full CRUD operations
- **Language synchronization** between lyrics and channels
- **YouTube account settings** in Settings dialog
- **Suno generation control space** at top of channels view
- **Channel properties**: title, handle, description, keywords, brand_category, visual_style, overall_style, channel_style, vibe
- **Channel status**: enable/disable toggle
- **Language management**: dropdown restricted to available lyrics languages, muted state for unavailable languages

### Backend Settings
- Extended settings storage to include YouTube account email, handle, and brand channel ID
- All settings properly saved and loaded

## 🔄 Ready for Integration

### 1. Suno API Integration
**Location**: Methods `_generateSongsForAllChannels()` and `_generateSongsForLanguages()` in `dashboard_screen.dart`

**What to implement**:
```dart
// Example integration pattern needed:
Future<void> _generateSongsForAllChannels(AppState state, Map<String, dynamic> project) async {
  final sunoToken = state.settings['suno']?['token'];
  final channels = (project['channels'] as List?)?.cast<Map>() ?? [];
  final lyrics = _ensureLyricsStructure(project);
  
  // For each enabled channel:
  for (final channel in channels.where((ch) => ch['enabled'] ?? true)) {
    final language = channel['language'] as String;
    final lyricContent = lyrics['blocks']
        ?.map((block) => (block['texts'] as Map?)?[language])
        .join('\n');
    
    // Call Suno API with:
    // - prompt: lyricContent
    // - tags: "${channel['overall_style']} ${channel['channel_style']}"
    // - mood/vibe: channel['vibe']
    
    // Example call structure:
    // await sunoApi.generateSongs(
    //   prompt: lyricContent,
    //   tags: channel['overall_style'],
    //   negative_tags: channel['vibe'],
    // );
  }
}
```

**Integration with sunoapi subproject**:
- The `/sunoapi` directory contains the Suno API wrapper
- Use `/sunoapi/src/lib/SunoApi.ts` methods:
  - `generateSongs()`: Main generation method
  - `generateLyrics()`: Alternative lyrics generation
- Ensure Suno token is retrieved from settings before calling

### 2. URL Launcher for YouTube
**Location**: `_launchUrl()` method and `_openYouTubeChannelCreation()` in `dashboard_screen.dart`

**What to implement**:
```dart
// Add to pubspec.yaml:
// url_launcher: ^6.x

import 'package:url_launcher/url_launcher.dart';

void _launchUrl(String urlString) async {
  final Uri url = Uri.parse(urlString);
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    _showSnack('Could not launch URL');
  }
}

// In _openYouTubeChannelCreation(), use:
_launchUrl('https://www.youtube.com/channel_list');
// Or for directly creating a channel:
_launchUrl('https://www.youtube.com/@${youtubeHandle}/edit/basics');
```

### 3. YouTube API Sync (Optional, Advanced)
**Location**: Create new methods in `dashboard_screen.dart` or backend service

**What to implement**:
```dart
Future<void> _syncChannelsWithYouTube(AppState state, Map<String, dynamic> project) async {
  // Use YouTube Data API v3 to:
  // 1. Fetch existing brand accounts
  // 2. Get channel properties for each
  // 3. Update local channel data
  
  // Required API methods:
  // - youtube.channels.list() - get channel details
  // - youtube.brandChannels.list() - get brand accounts
  // - youtube.channels.update() - push local changes to YouTube
  
  // Implementation would involve:
  // - Making HTTP calls with api_key from settings
  // - Parsing YouTube API responses
  // - Updating local channel data with fetched properties
}
```

## 📋 Channel Data Structure

Each channel now supports:
```json
{
  "channel_id": "channel_1",
  "language": "en",
  "title": "My Channel",
  "handle": "@mychannel",
  "description": "Channel description",
  "keywords": "music,ai,video",
  "brand_category": "Music",
  "overall_style": "cinematic",
  "channel_style": "energetic",
  "vibe": "upbeat",
  "visual_style": "stylized",
  "enabled": true
}
```

## 🎯 Generation Flow

When user clicks "Generate for All Channels":

1. **Retrieve Suno token** from `state.settings['suno']['token']`
2. **Get enabled channels** filtered by `enabled: true`
3. **For each channel:**
   - Extract language
   - Get lyrics for that language from project
   - Build generation prompt with:
     - Lyrics content
     - Overall style: `channel['overall_style']`
     - Channel style: `channel['channel_style']`
     - Vibe/mood: `channel['vibe']`
   - Call Suno API to generate song
   - Store generated song ID or audio URL in channel metadata (optional)

## 🔗 Settings Structure

YouTube settings now stored as:
```json
{
  "youtube": {
    "api_key": "YOUR_API_KEY",
    "account_email": "user@gmail.com",
    "account_handle": "@username",
    "brand_channel_id": "CHANNEL_ID",
    "channel_ids": [],
    "refresh_token": "",
    "access_token": ""
  }
}
```

## 📱 UI Screenshots (What Works Now)

### Settings Dialog
- New "YouTube Account" section with 4 fields:
  - YouTube API Key
  - Google Account Email
  - YouTube Channel Handle
  - Brand Account Channel ID

### Channels View
- **Top Control Space**: "Suno Song Generation" panel with:
  - "Generate for All Channels" button
  - "Generate by Language" button
  - "View Status" button
  - Helper text explaining the feature

- **Channel Cards**: Each showing all editable properties:
  - Enable/Disable checkbox
  - Basic info (ID, Title, Handle)
  - Description (2-line textarea)
  - Keywords and Brand Category
  - Style settings (Overall, Channel-specific, Visual, Vibe)
  - Language dropdown (connected to available lyrics languages)
  - Muted appearance when language unavailable
  - Delete button with confirmation

## ✨ Next Steps (Priority Order)

1. **High Priority** - Suno Integration
   - Implement actual Suno API calls in generation methods
   - Handle API response and errors
   - Show generation progress to user

2. **Medium Priority** - URL Launcher
   - Add url_launcher package to pubspec.yaml
   - Implement _launchUrl() with proper error handling
   - Test YouTube channel creation link

3. **Low Priority** - YouTube Sync
   - Implement YouTube API integration
   - Fetch channel properties automatically
   - Two-way sync between app and YouTube

## 📝 Testing Checklist

- [ ] Add YouTube account email in Settings → Integrations
- [ ] Create new channel
- [ ] Verify language dropdown shows only lyrics languages
- [ ] Add another language to Lyrics
- [ ] Re-open channels, verify new language appears in dropdown
- [ ] Remove language from Lyrics
- [ ] Verify channel now appears muted
- [ ] Edit channel properties
- [ ] Save project and reload - verify changes persisted
- [ ] Delete a channel (test confirmation dialog)
- [ ] Click "Open YouTube" button
- [ ] Click "Generate for All Channels" (currently shows placeholder)
- [ ] Enable/disable channels and verify checkbox state

## 🚀 Performance Notes

- Language dropdown filtered at widget build time - O(n) where n = languages
- Channel card rendering: O(c) where c = channels (consider virtualizing if >100 channels)
- No database calls needed (all data in project.json)
- Suno generation likely async - use Future builder for user feedback
