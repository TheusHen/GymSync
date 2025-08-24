# Background Services Implementation

This document describes the background services implementation for GymSync to ensure continuous location monitoring and workout tracking when the app is backgrounded.

## Problem
The original implementation used Flutter `Timer.periodic()` which gets suspended when the app goes to background, causing location monitoring and workout tracking to stop.

## Solution
Replaced timer-based approach with proper Android background services:

### 1. BackgroundLocationService (WorkManager)
- Uses `workmanager` package for periodic location checks every 15 minutes
- Monitors gym location and automatically starts/stops gym workouts
- Runs independently of the main app in a separate isolate
- Handles gym arrival/departure detection

### 2. ForegroundWorkoutService
- Uses `flutter_foreground_task` for continuous workout tracking
- Shows persistent notification during active workouts
- Updates workout status every 5 seconds
- Prevents system from killing the workout timer

### 3. AppStateService
- Monitors app lifecycle changes
- Ensures background services are running when app goes to background
- Syncs state when app returns to foreground

## Configuration

### Android Manifest Permissions
Required permissions added to `AndroidManifest.xml`:
- `ACCESS_BACKGROUND_LOCATION` - For location monitoring in background
- `FOREGROUND_SERVICE` - For foreground service
- `FOREGROUND_SERVICE_LOCATION` - For location-based foreground service
- `WAKE_LOCK` - To keep CPU awake during background tasks
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` - To prevent battery optimization from killing the app

### Dependencies
Added to `pubspec.yaml`:
- `workmanager: ^0.5.2` - For background location monitoring
- `flutter_foreground_task: ^8.11.0` - For foreground workout tracking

## Usage

### Initialization
Services are automatically initialized in `main.dart`:
```dart
await BackgroundLocationService.initialize();
await ForegroundWorkoutService.initialize();
AppStateService().initialize();
```

### Starting Location Monitoring
Automatically started when the app initializes:
```dart
await BackgroundLocationService().startLocationMonitoring();
```

### Starting Workout Tracking
Automatically started when a workout begins:
```dart
await ForegroundWorkoutService().startWorkoutTracking(activityType);
```

## Technical Details

### WorkManager Configuration
- Frequency: 15 minutes (minimum allowed by Android)
- Constraints: No network, battery, or charging requirements
- Policy: Replace existing tasks to prevent duplicates

### Foreground Service Configuration
- Channel: 'workout_tracking_channel'
- Update frequency: 5 seconds
- Icons: Uses app launcher icon
- Notification actions: None (controlled via main app UI)

### Error Handling
- All services include try-catch blocks for robustness
- Fallback to last known location if GPS fails
- Graceful degradation if services fail to start

## Testing
Run the background services tests:
```bash
flutter test test/background_services_test.dart
```

## Battery Optimization
The app requests users to disable battery optimization to ensure background services continue running. This is done through:
- `Permission.ignoreBatteryOptimizations.request()`
- Users may need to manually whitelist the app in device settings

## Limitations
- WorkManager minimum frequency is 15 minutes (Android limitation)
- Foreground service requires persistent notification
- Battery optimization may still affect background execution on some devices
- iOS implementation may require different approach (not included in this implementation)