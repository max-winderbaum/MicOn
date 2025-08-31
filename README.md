# MicOn - Bluetooth Headset Connection Keeper

A minimal macOS app that keeps your microphone active to prevent Bluetooth headset disconnections and eliminate activation latency.

## What It Does

MicOn solves a common problem with Bluetooth headsets on macOS: when the microphone isn't actively in use, headsets often disconnect or have annoying activation delays when you need to speak. This app keeps your microphone stream active without recording anything, ensuring your headset stays connected and ready.

## Features

- 🎙️ **Smart Microphone Activation** - Keeps mic active without recording data
- 🎨 **Beautiful Dark UI** - Modern interface with smooth animations
- 📊 **Menu Bar App** - Lives quietly in your menu bar
- 🚀 **Auto-Start** - Microphone activates automatically on launch
- 🎧 **Device Selection** - Choose which audio device to keep active
- 🔒 **Privacy First** - No audio is ever recorded, processed, or saved
- 🔄 **Multi-App Support** - Shares microphone access with other apps

## Installation

### Quick Install
1. Download the latest release from [Releases](https://github.com/yourusername/mic-on/releases)
2. Drag `MicOn.app` to your Applications folder
3. Launch MicOn from Applications
4. Grant microphone permission when prompted

### Build from Source
```bash
# Clone the repository
git clone https://github.com/yourusername/mic-on.git
cd mic-on

# Open in Xcode
open MicOn.xcodeproj

# Build and run (⌘+R)
```

## Usage

### First Launch
1. **Launch MicOn** - A green circle appears in your menu bar
2. **Grant Permission** - Click "OK" when macOS asks for microphone access
3. **That's it!** - Your microphone is now active and your headset will stay connected

### Daily Use
- **Menu Bar Icon**: Green circle indicates the app is running
- **Show/Hide Window**: Click the menu bar icon → "Show MicOn"
- **Toggle Microphone**: Click the large button in the app window
- **Change Device**: Use the dropdown to select a different microphone

### Launch at Startup
1. Open **System Settings** → **General** → **Login Items**
2. Click the **+** button under "Open at Login"
3. Select **MicOn** from Applications
4. The app will now start automatically when you log in

## Privacy & Security

### What MicOn Does
- ✅ Activates microphone stream to prevent disconnections
- ✅ Allows you to select which device to keep active
- ✅ Shares microphone access with other apps

### What MicOn Does NOT Do
- ❌ Does NOT record audio
- ❌ Does NOT save any data to disk
- ❌ Does NOT process or analyze audio
- ❌ Does NOT send data over the network
- ❌ Does NOT access other system resources

### Permissions
MicOn requires microphone permission to function. This permission is used solely to keep the audio stream active. You can revoke this permission at any time in System Settings → Privacy & Security → Microphone.

## Troubleshooting

### Microphone won't activate
1. Check System Settings → Privacy & Security → Microphone
2. Ensure MicOn is listed and enabled
3. Try toggling the permission off and on
4. Restart the app

### App doesn't appear in Microphone settings
1. Click the "Grant Microphone Access" button in the app
2. Or reset permissions in Terminal:
   ```bash
   tccutil reset Microphone com.yourcompany.MicOn
   ```
3. Restart MicOn

### Bluetooth headset still disconnects
1. Ensure MicOn is running (green circle in menu bar)
2. Select your specific Bluetooth device from the dropdown
3. Check that no other apps are exclusively capturing the microphone
4. Try restarting your Bluetooth connection

### Permission keeps being requested
1. Clean build in Xcode (⇧⌘K)
2. Delete MicOn from Applications
3. Rebuild and reinstall
4. Grant permission once more

## System Requirements

- **macOS**: 13.0 (Ventura) or later
- **Processor**: Apple Silicon or Intel
- **Permissions**: Microphone access

## How It Works

MicOn uses macOS audio APIs (`AVCaptureSession` or `AVAudioEngine`) to create an active audio input stream. However, unlike recording apps, it doesn't process or store the audio data - the stream simply stays open to keep your Bluetooth headset's microphone connection alive.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## License

MIT License - See LICENSE file for details

## Acknowledgments

Built with SwiftUI and AVFoundation for macOS.