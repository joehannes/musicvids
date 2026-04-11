# YouTube Channel Syncing, OAuth, and Channel Data Management

## 1. CHANNEL DATA STRUCTURES

### Channel Model (Frontend & Backend)
**File**: [app_flutter/lib/screens/dashboard_screen.dart](app_flutter/lib/screens/dashboard_screen.dart#L3594)
```dart
{
  'channel_id': String,              // Unique identifier 
  'youtube_channel_id': String,      // YouTube's actual channel ID
  'language': String,                // Content language (linked to lyrics)
  'title': String,                   // Channel name
  'handle': String,                  // @username
  'description': String,             // Full description
  'keywords': String,                // Comma-separated SEO keywords
  'brand_category': String,          // YouTube category
  'overall_style': String,           // Content generation style (e.g., "cinematic")
  'channel_style': String,           // Channel-specific branding
  'visual_style': String,            // Visual treatment
  'vibe': String,                    // Mood/atmosphere (e.g., "experimental")
  'enabled': bool,                   // Generation toggle
  
  // Read-only metadata from sync:
  '_yt_view_count': int              // From YouTube API
  '_yt_subscriber_count': int        // From YouTube API
  '_yt_video_count': int             // From YouTube API
  '_yt_keywords': String             // From YouTube API
  '_yt_synced_at': String            // Last sync timestamp
}
```

**Backend Schema**: [backend_python/app/models/schemas.py](backend_python/app/models/schemas.py#L32)
```python
class ChannelProfile(BaseModel):
    channel_id: str
    language: str
    title: str
    description: str
    overall_style: str = "cinematic"
    channel_style: str = ""
    vibe: str
    visual_style: str
    enabled: bool = True
```

### YouTube Settings Structure
**File**: [backend_python/app/services/settings_store.py](backend_python/app/services/settings_store.py)
```python
{
    "youtube": {
        "api_key": String,             # YouTube Data API v3 key
        "client_id": String,           # OAuth 2.0 Client ID (from Google Console)
        "client_secret": String,       # OAuth 2.0 Client Secret
        "oauth_token": String,         # Bearer token for API calls (auto-filled)
        "account_email": String,       # Google account email
        "account_handle": String,      # Channel handle (@username)
        "brand_channel_id": String,    # Brand account channel ID
        "channel_ids": List[String],   # List of managed channel IDs
        "refresh_token": String,       # (Future) for token refresh
        "access_token": String,        # (Future) alternative to oauth_token
    }
}
```

---

## 2. CURRENT SYNC/FETCH MECHANISM

### Main Sync Method
**File**: [app_flutter/lib/screens/dashboard_screen.dart](app_flutter/lib/screens/dashboard_screen.dart#L3277)
**Method**: `_syncAllChannels(AppState state)`

**What it does**:
- Fetches channel metadata from YouTube Data API v3
- Uses OAuth token for authentication
- Implements 3-strategy approach for channel discovery:
  1. **Strategy 1**: `mine=true` - Fetches authenticated user's primary channel
  2. **Strategy 2**: `forContentOwner=true` - Fetches channels where user is content owner
  3. **Strategy 3**: `managedByMe=true` - Fetches brand accounts linked to GSuite/Workspace

**Code Snippet** (excerpt):
```dart
void _syncAllChannels(AppState state) async {
    final project = state.activeProject;
    final youtubeSettings = state.settings['youtube'] as Map?;
    final oauthToken = youtubeSettings?['oauth_token'] as String?;

    if (oauthToken == null || oauthToken.isEmpty) {
      _showSnack('YouTube OAuth token not set in Settings...');
      return;
    }

    // Helper function to fetch from YouTube API with pagination
    Future<void> _fetchChannelsWithParams(String description, Map<String, String> params) async {
      String? pageToken;
      do {
        final requestParams = {...params};
        if (pageToken != null) {
          requestParams['pageToken'] = pageToken;
        }

        final url = Uri.https('www.googleapis.com', '/youtube/v3/channels', requestParams);
        final response = await http.get(
          url,
          headers: {'Authorization': 'Bearer $oauthToken'},
        );
        
        // Process response, extract channel data
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final responseItems = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          
          for (final item in responseItems) {
            final channelId = item['id'] as String?;
            final snippet = item['snippet'] as Map?;
            final statistics = item['statistics'] as Map?;
            
            // Extract and store metadata...
          }
          pageToken = data['nextPageToken'] as String?;
        }
      } while (pageToken != null);
    }

    // Execute all 3 strategies
    await _fetchChannelsWithParams('Strategy 1: Primary channel (mine=true)', {
      'part': 'snippet,statistics,contentDetails,brandingSettings,status',
      'mine': 'true',
      'maxResults': '50',
    });
    
    // Similar for Strategy 2 and 3...
}
```

**API Parameters Used**:
- `part`: `snippet,statistics,contentDetails,brandingSettings,status`
- `mine=true`: User's primary channel
- `forContentOwner=true`: Content owner channels
- `managedByMe=true`: Managed brand accounts
- `maxResults`: Pagination (50 per page)

**Data Extraction from API Response**:
```dart
final snippet = item['snippet'] as Map?;
final title = snippet?['title'] as String? ?? '';
final handle = snippet?['customUrl'] as String? ?? '';
final description = snippet?['description'] as String? ?? '';

final statistics = item['statistics'] as Map?;
final viewCount = int.tryParse(statistics?['viewCount']?.toString() ?? '0') ?? 0;
final subscriberCount = int.tryParse(statistics?['subscriberCount']?.toString() ?? '0') ?? 0;
final videoCount = int.tryParse(statistics?['videoCount']?.toString() ?? '0') ?? 0;

final branding = item['brandingSettings'] as Map?;
final keywords = branding?['channel']?['keywords'] as String? ?? '';
```

---

## 3. OAUTH CONNECTION TEST

**File**: [app_flutter/lib/screens/dashboard_screen.dart](app_flutter/lib/screens/dashboard_screen.dart#L3927)
**Method**: `_testOAuthConnection(AppState state)`

**What it does**:
- Validates OAuth token by making a test API call
- Returns HTTP 401 if token is invalid/expired
- Fetches user's accessible channels to verify permissions

**Code**:
```dart
void _testOAuthConnection(AppState state) async {
    final youtubeSettings = state.settings['youtube'] as Map?;
    final oauthToken = youtubeSettings?['oauth_token'] as String?;

    if (oauthToken == null || oauthToken.isEmpty) {
      _showSnack('No OAuth token found. Set up OAuth first in Settings.');
      return;
    }

    try {
      // Test call to get authenticated user's channels
      final userUrl = Uri.https('www.googleapis.com', '/youtube/v3/channels', {
        'part': 'id,snippet',
        'mine': 'true',
      });

      final userResponse = await http.get(
        userUrl,
        headers: {'Authorization': 'Bearer $oauthToken'},
      );

      if (userResponse.statusCode == 401) {
        _showSnack('❌ OAuth token is invalid or expired. Re-authorize in Settings.');
        return;
      }

      if (userResponse.statusCode == 200) {
        final userData = jsonDecode(userResponse.body) as Map<String, dynamic>;
        final items = (userData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final primaryChannel = items.first;
        final channelTitle = primaryChannel['snippet']?['title'] ?? 'Unknown';
        
        _showSnack('✅ OAuth Connection Valid!\n• Primary Channel: $channelTitle\n• Total accessible: ${items.length} channel(s)');
        return;
      }
    } catch (e) {
      _showSnack('❌ Error testing connection: $e');
    }
}
```

---

## 4. OAUTH SETUP FLOW

**File**: [app_flutter/lib/screens/dashboard_screen.dart](app_flutter/lib/screens/dashboard_screen.dart#L4098)
**Method**: `_startOAuthFlow(AppState state)`

**Requirements**:
- Client ID must be set in settings (from Google Console)
- Client Secret must be set in settings
- Requires user to authorize via browser

**Flow**:

1. **Prepare Authorization URL** with full scopes:
```dart
final scopes = [
  'https://www.googleapis.com/auth/youtube',                    // Full YouTube access
  'https://www.googleapis.com/auth/youtube.force-ssl',          // Force SSL
  'https://www.googleapis.com/auth/yt-analytics.readonly',      // Analytics
  'https://www.googleapis.com/auth/yt-analytics-monetary.readonly', // Monetization
].map((s) => Uri.encodeComponent(s)).join('%20');

final authUrl = 'https://accounts.google.com/o/oauth2/v2/auth?'
    'client_id=$clientId&'
    'redirect_uri=${Uri.encodeComponent('http://localhost:8080/oauth2callback')}&'
    'response_type=code&'
    'scope=$scopes&'
    'access_type=offline&'
    'prompt=consent';
```

2. **Launch browser** to authorization URL
3. **User grants permissions**
4. **Receives authorization code** (via redirect)
5. **Exchange code for token** via `_exchangeCodeForToken()`

**Token Exchange**:
```dart
Future<String?> _exchangeCodeForToken(String clientId, String clientSecret, String code, String redirectUri) async {
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
        return accessToken;
      }
    } catch (e) {
      _showSnack('Error exchanging code: $e');
    }
}
```

6. **Auto-saves token** to settings and clipboard

---

## 5. CHANNEL ADDITION DIALOG

### Manual Channel Addition
**File**: [app_flutter/lib/screens/dashboard_screen.dart](app_flutter/lib/screens/dashboard_screen.dart#L3594)
**Method**: `_showAddChannelDialog(AppState state)`

**Dialog Fields**:
- YouTube Channel ID (e.g., `UC...`)
- Channel Title (optional)

**Code**:
```dart
void _showAddChannelDialog(AppState state) async {
    final project = state.activeProject;
    if (project == null) {
      _showSnack('Load a project first.');
      return;
    }

    final channelIdController = TextEditingController();
    final channelTitleController = TextEditingController();
    
    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manually Add Channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: channelIdController,
              decoration: const InputDecoration(
                labelText: 'YouTube Channel ID (e.g., UC...)',
                hintText: 'Find in channel URL: youtube.com/channel/UC...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: channelTitleController,
              decoration: const InputDecoration(
                labelText: 'Channel Title',
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

    final channelId = channelIdController.text.trim();
    final channelTitle = channelTitleController.text.trim();

    // Validate and add
    final existingChannels = (project['channels'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    if (existingChannels.any((ch) => ch['channel_id'] == channelId)) {
      _showSnack('This channel is already in the project.');
      return;
    }

    // Get default language from project lyrics
    final lyrics = _ensureLyricsStructure(project);
    final defaultLang = ((lyrics['languages'] as List?)?.isNotEmpty ?? false)
        ? (lyrics['languages'] as List).first.toString()
        : 'en';

    existingChannels.add({
      'channel_id': channelId,
      'youtube_channel_id': '',
      'language': defaultLang,
      'title': channelTitle.isEmpty ? 'Manual Channel' : channelTitle,
      'handle': '',
      'description': '',
      'keywords': '',
      'brand_category': '',
      'overall_style': 'cinematic',
      'channel_style': '',
      'vibe': 'experimental',
      'visual_style': 'stylized',
      'enabled': true,
    });

    project['channels'] = existingChannels;
    state.touch();
    _scheduleAutosave(state);
    _showSnack('✅ Channel added manually. You can edit details in the channel list.');
}
```

### Batch/Pattern Channel Generation
**File**: [app_flutter/lib/screens/dashboard_screen.dart](app_flutter/lib/screens/dashboard_screen.dart#L1890)
**Button**: "Generate Pattern" button

Allows creating multiple channels via pattern:
- Prefix (e.g., "UC")
- Base name (e.g., "abc")
- Range pattern (e.g., "01...50")

---

## 6. CHANNEL ID vs HANDLE DISTINCTION

| Field | Purpose | Example | Set By |
|-------|---------|---------|---------|
| `channel_id` | **App's internal unique ID** | `channel_1`, `UC1234...` | Manual entry or auto-generated |
| `youtube_channel_id` | **YouTube's actual channel ID** | `UCabcdef123456...` | From YouTube API sync |
| `handle` | **@username** used for discovery | `@mychannel` | From YouTube API or manual entry |
| `title` | **Display name** | "My Music Channel" | From YouTube API or manual entry |

**Where they're used**:

1. **Channel ID** (`channel_id`):
   - Internal app identifier
   - Used in generation workflows
   - Stored in project['channels'] array
   - Used to filter channels for generation

2. **YouTube Channel ID** (`youtube_channel_id`):
   - From YouTube API response
   - Used for YouTube API calls (if needed)
   - Read-only metadata field

3. **Handle** (`handle`):
   - User-friendly identifier
   - Display in UI
   - SEO/discovery purposes

---

## 7. YOUTUBE API INTEGRATION POINTS

### YouTube Data API v3 Endpoints Used

**Channels.list** (Primary endpoint)
```
GET https://www.googleapis.com/youtube/v3/channels
Authorization: Bearer {oauth_token}

Parameters:
- part: snippet,statistics,contentDetails,brandingSettings,status
- mine: true|false
- forContentOwner: true|false
- managedByMe: true|false
- maxResults: 1-50
- pageToken: for pagination
```

**What data is extracted**:
```
item['id']                              → channel_id
item['snippet']['title']                → title
item['snippet']['customUrl']            → handle (@username)
item['snippet']['description']          → description
item['statistics']['viewCount']         → _yt_view_count
item['statistics']['subscriberCount']   → _yt_subscriber_count
item['statistics']['videoCount']        → _yt_video_count
item['brandingSettings']['channel']['keywords'] → _yt_keywords
```

### Authentication Methods
**File**: [app_flutter/lib/widgets/settings_dialog.dart](app_flutter/lib/widgets/settings_dialog.dart#L230)

```dart
// Settings fields for YouTube auth
youtubeKey = TextEditingController(text: widget.initial['youtube']?['api_key'] ?? '');
youtubeClientId = TextEditingController(text: widget.initial['youtube']?['client_id'] ?? '');
youtubeClientSecret = TextEditingController(text: widget.initial['youtube']?['client_secret'] ?? '');
youtubeOAuthToken = TextEditingController(text: widget.initial['youtube']?['oauth_token'] ?? '');
```

**Two auth types**:
1. **API Key** - Simple, read-only access for public data
2. **OAuth 2.0** - Full access to user's channels (current implementation)

---

## 8. CHANNEL DISPLAY AND EDITING

### Channels Page UI Builder
**File**: [app_flutter/lib/screens/dashboard_screen.dart](app_flutter/lib/screens/dashboard_screen.dart#L1837)
**Method**: `_channelsPage(AppState state)`

**UI Components**:
1. **Control Space** for Suno song generation
2. **Channel Management Header** with buttons:
   - Setup OAuth
   - Test Connection
   - Sync All
   - Export Channels
   - Import Channels
   - Add Manual
   - Generate Pattern
   - Open YouTube

3. **Channels Grid/List** showing all channels

### Channel Card Display
**File**: [app_flutter/lib/screens/dashboard_screen.dart](app_flutter/lib/screens/dashboard_screen.dart#L2166)
**Method**: `_buildYoutubeChannelCard()`

**Card shows**:
- Checkbox (enable/disable)
- Language dropdown (restricted to available lyrics languages)
- Title and handle fields
- Description (2-line textarea)
- Keywords and brand category
- Style fields (overall, channel-specific, visual, vibe)
- Sync and Delete buttons
- Muted state if language not in lyrics

**Language Validation**:
```dart
final isLanguageMuted = !availableLangs.contains(channelLang);

// Language dropdown disabled if muted
onChanged: isLanguageMuted ? null : (v) { /* update */ }
```

---

## 9. HELPER METHODS

### Export Channels
**File**: [app_flutter/lib/screens/dashboard_screen.dart](app_flutter/lib/screens/dashboard_screen.dart#L2684)
**Method**: `_exportChannels(AppState state)`
- Exports channels to JSON file or clipboard
- Includes all editable fields

### Import Channels
**File**: [app_flutter/lib/screens/dashboard_screen.dart](app_flutter/lib/screens/dashboard_screen.dart#L2749)
**Method**: `_importChannels(AppState state)`
- Imports channels from JSON file
- Confirmation dialog before merge
- Updates existing channels with same IDs

### Delete Channel
**File**: [app_flutter/lib/screens/dashboard_screen.dart](app_flutter/lib/screens/dashboard_screen.dart#L4197)
**Method**: `_deleteChannel(AppState state, int index)`
- Shows confirmation dialog
- Removes channel from project['channels']
- Triggers autosave

### Sync Single Channel
**File**: [app_flutter/lib/screens/dashboard_screen.dart](app_flutter/lib/screens/dashboard_screen.dart#L2679)
**Method**: `_syncChannel(appState state, Map<String, dynamic> channel)`
- Currently TODO - stub only
- Future implementation for single channel sync

---

## 10. BACKEND INTEGRATION

### Workflow Generation with Channels
**File**: [backend_python/app/api/routes/workflow.py](backend_python/app/api/routes/workflow.py#L23)
**Endpoints**:

```python
@router.post('/suno/{project_name}')
def generate_suno_songs(project_name: str, channel_ids: list[str] | None = None) -> dict:
    """Generate Suno songs for all or specific channels"""
    project = store.load_project(project_name).model_dump(mode='json')
    
    if channel_ids:
        project['channels'] = [ch for ch in project.get('channels', []) 
                              if ch['channel_id'] in channel_ids]
    
    return runner.run(project, from_step=WorkflowStep.songs, to_step=WorkflowStep.songs)

@router.post('/midjourney/{project_name}')
def generate_midjourney_images(project_name: str, channel_ids: list[str] | None = None) -> dict:
    """Generate Midjourney images for all or specific channels"""
    # Similar to suno endpoint
```

### Backend Settings Storage
**File**: [backend_python/app/services/settings_store.py](backend_python/app/services/settings_store.py)

Settings persisted in `~/.musicvids_studio/settings.json`:
```json
{
  "youtube": {
    "api_key": "",
    "client_id": "",
    "client_secret": "",
    "oauth_token": "",
    "account_email": "",
    "account_handle": "",
    "brand_channel_id": "",
    "channel_ids": [],
    "refresh_token": "",
    "access_token": ""
  }
}
```

---

## 11. SHORTCUTS AND NAVIGATION

**File**: [app_flutter/lib/state/app_state.dart](app_flutter/lib/state/app_state.dart#L27)

```dart
'navigate.channels': 'n c',        // Jump to Channels view
'search.channels': 's c',          // Search channels
'channel.sync': 'c s',             // Sync channels
'channel.new': 'c n',              // Create new channel
```

---

## 12. CURRENT LIMITATIONS & TODOs

1. **_syncChannel** (line 2679) - Single channel sync not implemented (currently stub)
2. **Refresh token** - Currently not used, could enable automatic token refresh
3. **Brand channel list** - Partial support via `managedByMe`, could be enhanced
4. **Error handling** - YouTube API errors (403, 400) handled but could provide more detail
5. **Pagination** - Truncates at 50 channels per strategy, could handle 30+ channel accounts

---

## 13. TEST SETUP INSTRUCTIONS

To set up YouTube API integration:

1. **Create OAuth 2.0 Credentials**:
   - Go to Google Cloud Console
   - Create new Desktop Application credentials
   - Download JSON file (contains client_id and client_secret)

2. **Add to Settings**:
   - Space → S O (Open Settings)
   - Go to "YouTube Account" section
   - Enter Client ID, Client Secret
   - Click "Setup OAuth" button

3. **Authorize**:
   - Browser opens, user grants permissions
   - Authorization code pasted back into app
   - Token auto-saved to settings

4. **Test Connection**:
   - Click "Test Connection" button
   - Confirms token is valid and channels accessible

5. **Sync Channels**:
   - Click "Sync All" button
   - Fetches all accessible channels from YouTube
   - Populates channel list

---

## DIRECTORY STRUCTURE REFERENCE

```
app_flutter/
├── lib/
│   ├── screens/
│   │   └── dashboard_screen.dart        ← Main implementation
│   ├── widgets/
│   │   └── settings_dialog.dart         ← OAuth/YouTube settings
│   ├── services/
│   │   ├── backend_client.dart          ← API client
│   │   └── local_storage_service.dart
│   └── state/
│       └── app_state.dart               ← State management

backend_python/
├── app/
│   ├── services/
│   │   ├── settings_store.py            ← Settings schema
│   │   └── project_store.py
│   ├── api/
│   │   └── routes/
│   │       └── workflow.py              ← Generation endpoints
│   └── models/
│       └── schemas.py                   ← ChannelProfile model

docs/
├── CHANNELS_WIDGET_DELIVERY.md          ← Delivery summary
├── YOUTUBE_CHANNELS_IMPLEMENTATION.md   ← Full implementation guide
└── IMPLEMENTATION_DETAILS.md            ← Technical details
```
