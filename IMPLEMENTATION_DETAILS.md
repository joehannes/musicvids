# Implementation Details - Files and Changes

## Modified Files

### 1. Backend Settings Schema
**File**: `/home/hector/.local/git/musicvids/backend_python/app/services/settings_store.py`

**Changed**:
```python
# OLD: 
"youtube": {"api_key": "", "channel_ids": []}

# NEW:
"youtube": {
    "api_key": "",
    "account_email": "",
    "account_handle": "",
    "channel_ids": [],
    "brand_channel_id": "",
    "refresh_token": "",
    "access_token": "",
}
```

---

### 2. Settings Dialog - YouTube Account Fields
**File**: `/home/hector/.local/git/musicvids/app_flutter/lib/widgets/settings_dialog.dart`

**Changes**:
1. Added 3 new TextEditingController fields:
   - `youtubeEmail`
   - `youtubeHandle`
   - `youtubeBrandChannelId`

2. Updated `initState()`:
   ```dart
   youtubeEmail = TextEditingController(text: widget.initial['youtube']?['account_email'] ?? '');
   youtubeHandle = TextEditingController(text: widget.initial['youtube']?['account_handle'] ?? '');
   youtubeBrandChannelId = TextEditingController(text: widget.initial['youtube']?['brand_channel_id'] ?? '');
   ```

3. Updated `dispose()`:
   - Properly disposes new controllers

4. Updated UI in `build()`:
   - Added "YouTube Account" section header
   - Added 4 text input fields organized in a group
   - Updated save action to include all YouTube account details

---

### 3. Dashboard Screen - Enhanced Channels Widget
**File**: `/home/hector/.local/git/musicvids/app_flutter/lib/screens/dashboard_screen.dart`

**Major Changes**:

#### New Methods Added:
1. **`_channelsPage()`** - Completely rewritten
   - Gets available languages from lyrics
   - Builds control space for Suno
   - Displays channel management header
   - Renders channel cards with full UI
   - Implements muted language logic

2. **`_buildSunoControlSpace()`** - NEW
   - Displays generation controls at top
   - Shows buttons for generation modes
   - Helper text for users

3. **`_openYouTubeChannelCreation()`** - NEW
   - Retrieves YouTube credentials from settings
   - Validates before opening
   - Opens YouTube channel management page

4. **`_launchUrl()`** - NEW
   - Ready for url_launcher integration
   - Currently shows URL in snackbar

5. **`_deleteChannel()`** - NEW
   - Confirmation dialog
   - Removes channel from project
   - Updates state

6. **`_generateSongsForAllChannels()`** - NEW
   - Placeholder for Suno generation
   - All channel data available for API call
   - Ready for implementation

7. **`_generateSongsForLanguages()`** - NEW
   - Placeholder for language-specific generation

#### Modified Methods:
- **`_addChannel()`** - Enhanced
  - Now initializes all channel properties
  - Defaults to first lyrics language
  - Includes all brand channel properties

#### Channel Card UI:
```
┌─────────────────────────────────────┐
│ ☑ [Channel ID] ... [Delete Button]  │  <- Enable toggle + ID + Delete
│                                      │
│ Language: [Dropdown ▼]  (linked)    │  <- Language sync with lyrics
│                                      │
│ [Title field]         [Handle field]│  <- Basic info
│                                      │
│ [Description ⌕⌕]                    │  <- 2-line textarea
│                                      │
│ [Keywords] [Brand Category]         │  <- Metadata
│                                      │
│ [Overall Style] [Channel Style]     │  <- Generation styles
│ [Visual Style] [Vibe/Mood]          │
│                                      │
│ ⓘ Language not in Lyrics...         │  <- Muted state info
└─────────────────────────────────────┘
```

---

## New Widget Structure

### Control Space (Top of Channels View)
```dart
Card (primaryContainer background) {
  "Suno Song Generation" header
  Explanation text
  [Generate for All Channels] button
  [Generate by Language] button
  [View Status] button
}
```

### Channel Card Properties
```
Status Fields:
- enabled (checkbox)
- channel_id (text)

Dropdowns:
- language (synced with lyrics, restricted)

Text Fields:
- title
- handle
- description (2-line)
- keywords
- brand_category
- overall_style
- channel_style
- vibe
- visual_style

Actions:
- Delete button
```

---

## Data Flow

### Settings Save:
```
Settings Dialog
    ↓
YouTube Account fields captured
    ↓
settings_dialog.dart → returns updated settings map
    ↓
app_state.dart → state.saveSettings()
    ↓
backend_client.dart → PUT /api/settings
    ↓
settings_store.py → save to disk
```

### Channel Management:
```
Channels View (_channelsPage)
    ↓
Gets lyrics languages
    ↓
For each channel:
    - Check if language in lyrics
    - Set muted state if not
    - Show all properties
    - Enable editing if not muted
    ↓
On changed: state.touch()
    ↓
Persisted to project['channels']
```

### Suno Generation:
```
User clicks "Generate for All Channels"
    ↓
_generateSongsForAllChannels() called
    ↓
Filters enabled channels
    ↓
For each channel:
    - Gets language
    - Gets lyrics for language
    - Extracts: overall_style, channel_style, vibe
    ↓
Ready to call Suno API
    ↓
Results stored/displayed to user
```

---

## Variable Names and Types

### New TextControllers in SettingsDialog:
- `youtubeEmail: TextEditingController`
- `youtubeHandle: TextEditingController`
- `youtubeBrandChannelId: TextEditingController`

### New Methods:
- `_buildSunoControlSpace(AppState state, Map project, List<String> langs) → Widget`
- `_openYouTubeChannelCreation(AppState state) → void`
- `_launchUrl(String urlString) → void`
- `_deleteChannel(AppState state, int index) → void`
- `_generateSongsForAllChannels(AppState state, Map project) → Future<void>`
- `_generateSongsForLanguages(AppState state, Map project, List<String> langs) → Future<void>`

### Channel Model Fields (in project['channels']):
```dart
{
  'channel_id': String,
  'language': String,
  'title': String,
  'handle': String,
  'description': String,
  'keywords': String,
  'brand_category': String,
  'overall_style': String,
  'channel_style': String,
  'vibe': String,
  'visual_style': String,
  'enabled': bool,
}
```

### Settings Model Fields (in settings['youtube']):
```dart
{
  'api_key': String,
  'account_email': String,
  'account_handle': String,
  'channel_ids': List,
  'brand_channel_id': String,
  'refresh_token': String,
  'access_token': String,
}
```

---

## Error Handling & Validation

### YouTube Channel Creation:
```dart
if (accountEmail == null || accountEmail.isEmpty) {
  _showSnack('Set your YouTube account email in Settings first.');
  return;
}
```

### Language Dropdown:
```dart
// Disabled if language not in lyrics
onChanged: isLanguageMuted ? null : (v) { ... }

// Visual feedback:
Opacity(
  opacity: isLanguageMuted ? 0.6 : 1.0,
  ...
)
```

### Channel Deletion:
```dart
// Confirmation required
showDialog { "Are you sure?" ... }

// Validate index before removal
if (index >= 0 && index < channels.length)
```

### Suno Generation:
```dart
// Check if token exists
if (state.settings['suno']?['token'] != null && ...)
  // Enable button
else
  // Disable button
```

---

## Integration Points Ready for Implementation

### 1. URL Launcher
**Status**: Ready for url_launcher package

**Files to Update**:
- `pubspec.yaml` - Add `url_launcher: ^6.x`
- `_launchUrl()` - Uncomment/implement launching logic

**Current Code**:
```dart
void _launchUrl(String urlString) {
  // TODO: Use url_launcher to open URL
  _showSnack('Open in browser: $urlString');
}
```

**Implementation Needed**:
```dart
import 'package:url_launcher/url_launcher.dart';

void _launchUrl(String urlString) async {
  final Uri url = Uri.parse(urlString);
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    _showSnack('Could not launch URL');
  }
}
```

### 2. Suno API Integration
**Status**: Scaffolded with all parameters ready

**Method**: `_generateSongsForAllChannels()`

**Parameters Available**:
- `sunoToken` from settings
- Per-channel: `language`, `overall_style`, `channel_style`, `vibe`
- Lyrics content from project

**Next Step**: Call Suno API endpoint with these parameters

### 3. YouTube API Integration
**Status**: Methods stub ready

**Methods**: 
- `_openYouTubeChannelCreation()` - Can expand with API calls
- Future method for sync can be added

**Parameters Available**:
- `youtubeKey` from settings
- Channel properties ready for Push
- Support for fetching existing channels

---

## Code Quality Metrics

- **Dart Analyzer**: ✅ No errors or warnings
- **Type Safety**: ✅ All variables properly typed
- **Imports**: ✅ All required imports present
- **Controller Disposal**: ✅ Proper cleanup in dispose()
- **State Management**: ✅ Uses Provider pattern correctly
- **UI Responsiveness**: ✅ Column/Row/Expanded for layout
- **Accessibility**: ✅ Labels, tooltips, helper text included

---

## Performance Characteristics

- **Language Filtering**: O(n) where n = available languages (typically 5-10)
- **Channel Rendering**: O(c) where c = channels (typically 1-10)
- **UI Build**: Efficient with const constructors where possible
- **State Updates**: Batched with `state.touch()`
- **Memory**: Minimal overhead from new controllers (cleaned up in dispose)

---

## Testing Recommendations

**Unit Test Areas**:
1. Channel CRUD operations
2. Language validation logic
3. Muted state calculation
4. Settings serialization/deserialization

**Widget Test Areas**:
1. Channel card rendering
2. Dropdown filtering
3. Delete confirmation dialog
4. Enable/disable toggle

**Integration Test Areas**:
1. Settings → Channels data flow
2. Lyrics changes → Channel language availability
3. Full generation workflow (after Suno integration)
