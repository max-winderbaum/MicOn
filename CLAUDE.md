# MicOn - Technical Documentation

## Project Overview
MicOn is a macOS app that keeps Bluetooth headsets connected by maintaining an active microphone stream without recording any data. This solves the common issue where Bluetooth headsets disconnect or have activation latency when the microphone isn't in use.

## Architecture

### Core Components

#### 1. **MicOnApp.swift** - Main Application Entry
- SwiftUI app using `@NSApplicationDelegateAdaptor` for AppKit integration
- Manages both window-based UI and menu bar presence
- App runs as `.accessory` (no dock icon, lives in menu bar)

#### 2. **AppState** - Central State Management
- Singleton pattern (`AppState.shared`)
- Manages microphone activation using two approaches:
  1. **Primary**: `AVCaptureSession` with minimal resource usage
  2. **Fallback**: `AVAudioEngine` with nil format (native hardware format)
- Device discovery via `AVCaptureDevice.DiscoverySession`
- Permission management with `AVCaptureDevice.requestAccess`

#### 3. **ContentView.swift** - User Interface
- Dark gradient background with modern aesthetic
- Custom dropdown implementation (native Menu styling was inadequate)
- Fixed-size container for button to prevent UI jank
- Shows privacy message: "No audio is being recorded or saved"

### Microphone Activation Strategy

The app uses a dual-approach strategy for maximum compatibility:

```swift
// Primary: AVCaptureSession (better for sharing)
captureSession.sessionPreset = .low
let output = AVCaptureAudioDataOutput()
output.setSampleBufferDelegate(nil, queue: nil) // No processing
```

```swift
// Fallback: AVAudioEngine (if capture fails)
input.installTap(onBus: 0, bufferSize: 256, format: nil) { buffer, time in
    // Empty - no processing
}
```

### Key Technical Decisions

1. **No Audio Recording**: The app installs audio taps/outputs but provides no delegates or handlers, ensuring audio data is never processed or stored.

2. **Shared Microphone Access**: Uses non-exclusive audio session configuration to allow multiple apps to access the microphone simultaneously.

3. **Menu Bar Design**: Always shows a green circle icon (not a microphone) for consistent branding. The icon doesn't change color to avoid confusion.

4. **Permission Handling**: 
   - Checks authorization status before each activation
   - Shows system settings button if permission denied
   - Added entitlements file for proper sandboxing

## Build Configuration

### Project Structure
```
MicOn/
├── MicOnApp.swift           # Main app & AppDelegate
├── ContentView.swift         # UI implementation
├── Info.plist               # App metadata & permissions
├── MicOn.entitlements       # Sandbox & microphone access
└── Assets.xcassets/
    └── AppIcon.appiconset/  # Green circle icons (16-1024px)
```

### Key Settings
- **Bundle ID**: `com.yourcompany.MicOn`
- **Deployment Target**: macOS 13.0+
- **Swift Version**: 5.0
- **Hardened Runtime**: Enabled
- **Entitlements**: 
  - `com.apple.security.device.audio-input`
  - `com.apple.security.device.microphone`

### Xcode Project Configuration
- Uses manually created `project.pbxproj` with simplified structure
- Assets catalog properly linked for app icon
- Info.plist includes `NSMicrophoneUsageDescription`
- `LSUIElement = true` for menu bar only app

## Known Issues & Solutions

### 1. Permission Loop Issue
**Problem**: App kept asking for permission even when granted.
**Solution**: Added entitlements file and proper authorization checking.

### 2. Audio Format Mismatch
**Problem**: `AVAudioEngine` threw format mismatch errors.
**Solution**: Use `nil` format to let system use native hardware format.

### 3. Menu Bar Icon Cutoff
**Problem**: SF Symbol microphone was cut off in menu bar.
**Solution**: Switched to simple green circle drawn with `NSBezierPath`.

### 4. Project File Corruption
**Problem**: Manual edits to `project.pbxproj` caused Xcode errors.
**Solution**: Recreated clean project file with new UUIDs.

## Console Messages (Normal)
These CMIO/HAL messages are normal and don't indicate errors:
- `CMIO_DAL_CMIOExtension_Device.mm:355:Device legacy uuid isn't present`
- `HALC_ProxyIOContext.cpp:1074 HALC_ProxyIOContext::_StartIO()`

These occur when macOS audio subsystem initializes devices, especially with virtual cameras or Bluetooth audio.

## Building & Installing

### Development Build
1. Open `MicOn.xcodeproj` in Xcode
2. Clean Build Folder (⇧⌘K)
3. Build and Run (⌘R)

### Release Build
1. Edit Scheme → Build Configuration → Release
2. Build (⌘B)
3. Find app in `Products/Release/`
4. Copy to `/Applications/`

### Icon Generation
Icons created programmatically using Python/Pillow:
```python
# Simple green circle at various sizes
green_color = (52, 199, 89)  # RGB
draw.ellipse([margin, margin, size - margin, size - margin], fill=green_color)
```

## Future Improvements
- Add preference for auto-start on launch
- Support for selecting specific Bluetooth devices
- Activity monitoring to show when mic is being accessed by other apps
- Keyboard shortcut for quick toggle