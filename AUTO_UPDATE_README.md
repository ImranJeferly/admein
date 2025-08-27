# Auto-Update Feature Configuration

This document explains how to configure and use the auto-update functionality that has been added to your Flutter app.

## Setup Instructions

### 1. Configure GitHub Repository

In `lib/services/update_service.dart`, update the GitHub API URL:

```dart
// TODO: Replace USERNAME/REPO with your actual GitHub repository
// Example: https://api.github.com/repos/myusername/admain-app/releases/latest
static const String _githubApiUrl = 'https://api.github.com/repos/USERNAME/REPO/releases/latest';
```

**Replace:**
- `USERNAME` with your GitHub username
- `REPO` with your repository name

**Example:**
```dart
static const String _githubApiUrl = 'https://api.github.com/repos/john-doe/admain-app/releases/latest';
```

### 2. Creating GitHub Releases

To trigger app updates, create releases on GitHub:

1. Go to your GitHub repository
2. Click "Releases" → "Create a new release"
3. Set the tag version (e.g., `v1.1.0`, `v1.2.0`)
4. Upload your APK file as an asset
5. Publish the release

### 3. Version Management

The app compares versions from:
- **Current version**: From `pubspec.yaml` → `version: 1.0.0+1` 
- **Latest version**: From GitHub release `tag_name`

**Important:** Use semantic versioning (e.g., v1.2.3) for proper version comparison.

## How It Works

### Startup Check
Every time the app is opened (not just backgrounded/foregrounded), it:
1. Calls GitHub API to get latest release info
2. Compares current app version with latest release tag
3. Shows update dialog if newer version is available

### Update Process
When user accepts the update:
1. Downloads APK from GitHub release assets
2. Shows progress bar during download
3. Launches Android installer after download completes

### Error Handling
- API failures: Logged and app continues normally
- Download failures: Error dialog with option to close
- Installation failures: Error dialog with details

## Files Added/Modified

### New Files:
- `lib/services/update_service.dart` - Main update logic
- `AUTO_UPDATE_README.md` - This documentation

### Modified Files:
- `pubspec.yaml` - Added dependencies:
  - `ota_update: ^6.0.0`
  - `package_info_plus: ^8.0.0`
- `lib/main.dart` - Added update check on app startup
- `android/app/src/main/AndroidManifest.xml` - Added permissions:
  - `WRITE_EXTERNAL_STORAGE`
  - `READ_EXTERNAL_STORAGE`
  - `REQUEST_INSTALL_PACKAGES`

## Testing the Update Feature

### 1. Test Version Comparison
- Current app version: Check `pubspec.yaml`
- Create a GitHub release with higher version number
- App should show update dialog

### 2. Test Update Process
- Accept the update in the dialog
- Verify download progress is shown
- Confirm Android installer launches

### 3. Test Error Scenarios
- Try with invalid GitHub URL (should fail gracefully)
- Try with no internet connection (should continue app normally)

## Customization Options

### Update Dialog Text
In `update_service.dart`, you can modify the Azerbaijani text:
- `'Yeniləmə mövcuddur!'` - "Update available!"
- `'Yeni versiya mövcuddur:'` - "New version available:"
- `'Yeniləməni indi quraşdırmaq istəyirsiniz?'` - "Do you want to install the update now?"

### Update Check Frequency
Currently checks on every app startup. To modify:
- Change the call location in `main.dart`
- Add timer-based checks in `app_state_service.dart`

### UI Styling
Update dialog uses your app's existing color scheme:
- Background: `Color(0xFF2a2e6a)` (dark blue)
- Accent: `Color(0xFFffc107)` (yellow)
- Modify in `_showUpdateDialog()` method

## Security Considerations

1. **HTTPS Only**: Always use HTTPS GitHub URLs
2. **Verify APK Source**: Only download from your official GitHub releases
3. **Version Validation**: App validates version format before comparing
4. **Permission Requests**: User must grant installation permissions

## Troubleshooting

### Common Issues:
1. **"No update found"** - Check GitHub release tag format (should be v1.2.3)
2. **Download fails** - Verify APK is uploaded as release asset
3. **Installation fails** - Ensure app has installation permissions
4. **API timeout** - Check internet connection and GitHub API limits

### Debug Logs:
The update service provides detailed logs prefixed with:
- `🔄 [UPDATE]` - General update process
- `📥 [UPDATE]` - Download process  
- `📱 [UPDATE]` - Installation process
- `❌ [UPDATE]` - Errors
- `✅ [UPDATE]` - Success messages

## Production Deployment

Before releasing to production:

1. ✅ Update GitHub repository URL in `update_service.dart`
2. ✅ Test with actual GitHub releases
3. ✅ Verify APK signing for installation
4. ✅ Test update flow on target devices
5. ✅ Confirm version numbering strategy