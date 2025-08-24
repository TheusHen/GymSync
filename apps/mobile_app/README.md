# GymSync Mobile App

The mobile Flutter application for GymSync that tracks workouts and gym sessions with Discord integration.

## Background Services Fix

This app now includes **proper background execution** to solve the issue where timers and location monitoring would stop when the app was backgrounded.

### ✅ Fixed Issues:
- **Timer suspension**: Workout timers no longer stop when app goes to background
- **Location monitoring**: Gym location detection continues running in background  
- **Activity tracking**: Automatic workout detection persists across app states
- **State synchronization**: App state stays consistent when returning from background

### 🔧 Technical Implementation:
- **WorkManager**: Periodic location monitoring every 15 minutes
- **Foreground Service**: Continuous workout tracking with persistent notification
- **App Lifecycle Management**: Automatic service management based on app state
- **Battery Optimization**: Requests whitelist to prevent system killing

For detailed technical documentation, see [BACKGROUND_SERVICES.md](BACKGROUND_SERVICES.md).

## Backend Service

> [!TIP]  
> The `_baseUrl` is already set to use a public backend provided by TheusHen to simplify builds and development.  
>  
> You are free to replace it with your own backend URL if you prefer.

### About `_baseUrl`

In the file `BackendService.dart`, the constant `_baseUrl` points to a public backend API:

```dart
static const String _baseUrl = 'https://gymsync-backend-orcin.vercel.app/api/v1/status';
```

## Features

- 🏋️ **Automatic Gym Detection**: Automatically starts/stops workouts when entering/leaving gym
- 📍 **Background Location Monitoring**: Continues monitoring gym location when app is backgrounded
- ⏱️ **Persistent Workout Tracking**: Workout timers continue running in background
- 🎮 **Discord Integration**: Shows workout status on Discord Rich Presence
- 📱 **Activity Recognition**: Automatically detects walking and other activities
- 🔔 **Smart Notifications**: Workout progress notifications with pause/stop actions

## Setup

1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Run the app: `flutter run`

### Permissions

The app will request the following permissions:
- **Location (Always)**: For gym detection and background monitoring
- **Activity Recognition**: For automatic workout detection
- **Notifications**: For workout alerts and persistent tracking
- **Battery Optimization Whitelist**: To ensure background services continue running

## Architecture

### Background Services
- `BackgroundLocationService`: WorkManager-based location monitoring
- `ForegroundWorkoutService`: Foreground service for workout tracking
- `AppStateService`: App lifecycle and state management

### Core Services  
- `BackendService`: API communication with GymSync backend
- `GoogleFitService`: Health data and activity recognition
- `NotificationService`: Local notifications management
- `LocationService`: Gym location setup and management

## Testing

Run tests with:
```bash
flutter test
```

## Platform Support

Currently optimized for **Android**. iOS support may require additional configuration for background execution.

## Troubleshooting

If background tracking stops working:
1. Check that battery optimization is disabled for GymSync
2. Ensure location permissions are set to "Allow all the time"
3. Verify notification permissions are granted
4. Check that the app hasn't been force-stopped by the system
