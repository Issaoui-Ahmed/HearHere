# HearHere

HearHere is an iOS application designed for location-based audio sharing. Users can record short clips tied to their current location and discover drops left by themselves or other community members when they visit the same spot.

## Features

- 📍 **Map-first experience** – View your position and nearby audio drops on an interactive map.
- 🎙️ **Location-aware recording** – Capture a note and attach it to your current GPS coordinates.
- 🎧 **Instant playback** – Listen to drops by tapping on map annotations or through the carousel of nearby clips.
- 🔐 **Permission handling** – Gracefully handles location and microphone permissions with user guidance.

## Getting Started

1. Open `HearHere.xcodeproj` in Xcode 15 or newer.
2. Select the `HearHere` scheme and choose an iOS simulator or a connected device.
3. Build and run (`⌘R`).

> **Tip:** The app requires location and microphone permissions. In the simulator you can simulate a custom location via **Features → Location**.

## Project Structure

```
HearHere/
├─ HearHereApp.swift           // App entry point
├─ ContentView.swift           // Root SwiftUI view with map and controls
├─ Models/                     // Domain models (AudioDrop)
├─ ViewModels/                 // Observable view models powering the UI
├─ Managers/                   // Location, audio recording, playback, and persistence helpers
├─ Resources/Assets.xcassets   // Color and icon assets
└─ Info.plist                  // App configuration & permission strings
```

## Next Steps

- Connect a real backend or cloud storage for sharing drops between devices.
- Add authentication so drops can be attributed to specific users.
- Enhance audio management (duration limits, waveforms, etc.).

## Requirements

- Xcode 15+
- iOS 16.0+ deployment target (configurable in project settings)

Enjoy leaving sounds for others to discover! 🔊
