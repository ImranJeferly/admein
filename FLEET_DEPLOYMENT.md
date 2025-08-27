# 🚕 Taxi Fleet Auto-Update System

## Overview
This system enables **over-the-air (OTA) updates** for 200 taxi tablets without requiring physical access to each device.

## How It Works

### 1. Code Changes & Deployment
```bash
# 1. Make your changes (bug fixes, new features, etc.)
git add .
git commit -m "Fix: Updated taxi fare calculation"
git push origin main

# 2. Create a new release version
git tag v1.0.2
git push origin v1.0.2
```

### 2. Automatic APK Build
- GitHub Actions automatically builds APK when you push tags
- Creates release with downloadable APK file
- Takes ~5-10 minutes to complete

### 3. Fleet Auto-Update
- All 200 tablets check for updates on app startup
- When new version detected: automatic download & install
- No driver intervention required
- Updates happen during normal taxi operations

## Fleet Management Features

### ✅ Automatic Updates
- **Zero touch deployment** - no physical access needed
- **Mandatory updates** - cannot be skipped by drivers
- **Background installation** - doesn't interrupt taxi operations
- **Fleet synchronization** - all tablets stay on same version

### ✅ Fleet Monitoring
- Device ID tracking for each tablet
- Update success/failure logging
- Version tracking across entire fleet
- Error handling for network issues

### ✅ Taxi-Optimized
- Updates during idle time
- Minimal disruption to taxi service
- Automatic retry on failed updates
- Robust error handling

## Deployment Process

### Initial Setup (One-time)
1. Install APK on all 200 tablets
2. Ensure tablets have internet connectivity
3. Configure GitHub repository access
4. Test update process on pilot tablets

### Regular Updates
1. **Developer**: Push code changes to GitHub
2. **GitHub**: Builds APK automatically
3. **Tablets**: Detect and download updates
4. **Fleet**: All tablets updated within hours

## Version Management

### Current Version: `v1.0.1`
### Next Version: `v1.0.2` (red background test)

### Semantic Versioning
- `v1.0.x` - Bug fixes and minor updates
- `v1.1.x` - New features
- `v2.0.x` - Major changes

## Emergency Updates

For critical bug fixes:
```bash
git tag v1.0.3-hotfix
git push origin v1.0.3-hotfix
```
All tablets will receive the hotfix within hours.

## Monitoring & Support

### Logs to Monitor
- `🚕 [FLEET-UPDATE]` - Update system logs
- `🔄 [FLEET-UPDATE]` - Version checks
- `📥 [UPDATE]` - Download progress
- `✅ [FLEET-UPDATE]` - Successful updates

### Troubleshooting
- Check GitHub Actions for build failures
- Monitor tablet logs for update errors
- Verify internet connectivity on tablets
- Check APK permissions on Android devices

## Benefits

### Before Auto-Update
- ❌ Visit 200 taxis individually
- ❌ Remove tablets manually
- ❌ Install updates one by one
- ❌ Days/weeks for full fleet update
- ❌ High operational cost

### With Auto-Update
- ✅ Single GitHub commit
- ✅ Automatic APK build
- ✅ Fleet-wide update in hours
- ✅ Zero physical intervention
- ✅ Minimal operational cost

---

**🎯 Result: Manage 200 taxi tablets from your computer with a single git push!**