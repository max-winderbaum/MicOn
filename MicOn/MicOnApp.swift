import SwiftUI
import AVFoundation
import AppKit

@main
struct MicOnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // No window group - app runs entirely from menu bar
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var appState: AppState?
    var window: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize app state
        appState = AppState.shared
        
        setupMenuBar()
        
        // Hide dock icon but keep app running
        NSApp.setActivationPolicy(.accessory)
        
        // Create and show the window
        createMainWindow()
        showApp()
    }
    
    func createMainWindow() {
        if window == nil {
            let contentView = ContentView()
                .environmentObject(appState ?? AppState.shared)
            
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 620),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            window?.center()
            window?.setFrameAutosaveName("Main Window")
            window?.contentView = NSHostingView(rootView: contentView)
            window?.title = "MicOn"
            window?.isReleasedWhenClosed = false
            window?.isMovableByWindowBackground = true
        }
    }
    
    func setupMenuBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        updateStatusIcon(isActive: false)
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show MicOn", action: #selector(showApp), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusBarItem.menu = menu
    }
    
    func updateStatusIcon(isActive: Bool) {
        if let button = statusBarItem.button {
            // Create a simple green circle for the menu bar
            let size = NSSize(width: 18, height: 18)
            let image = NSImage(size: size)
            
            image.lockFocus()
            
            // Draw a green circle
            let greenColor = NSColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1.0)
            greenColor.setFill()
            
            let path = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 14, height: 14))
            path.fill()
            
            image.unlockFocus()
            
            image.isTemplate = false
            button.image = image
        }
    }
    
    @objc func showApp() {
        createMainWindow()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isMicrophoneActive = false
    @Published var selectedDevice: AVCaptureDevice?
    @Published var availableDevices: [AVCaptureDevice] = []
    
    // Persistent device preference
    @Published var preferredDeviceID: String?
    @Published var currentlyUsingFallback = false
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var captureSession: AVCaptureSession?
    private var mixerNode: AVAudioMixerNode?
    private var pollingTimer: Timer?
    private var lastSuccessfulDevice: AVCaptureDevice?
    private var audioLevelMonitor: AVAudioPlayerNode?
    private var hasRecentAudioInput = false
    private var lastAudioInputTime: Date?
    
    init() {
        loadPreferredDevice()
        refreshDevices()
        requestMicrophonePermission()
        setupDeviceChangeNotifications()
        
        // Start with microphone on by default after permissions are granted
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            // Only start if we have permission
            if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                self?.startMicrophone()
                self?.startPollingTimer()
            }
        }
    }
    
    func refreshDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        availableDevices = discoverySession.devices
        
        // Try to restore preferred device if available
        if let preferredID = preferredDeviceID,
           let preferredDevice = availableDevices.first(where: { $0.uniqueID == preferredID }) {
            selectedDevice = preferredDevice
        } else if selectedDevice == nil, let first = availableDevices.first {
            selectedDevice = first
            
            // Auto-select first device as preferred on initial startup
            if preferredDeviceID == nil {
                setDefaultPreferredDevice()
            }
        }
    }
    
    private func setDefaultPreferredDevice() {
        // Prefer external devices (Bluetooth) over built-in microphone
        let preferredDevice = availableDevices.first { $0.deviceType == .externalUnknown } 
                           ?? availableDevices.first { $0.deviceType == .builtInMicrophone }
                           ?? availableDevices.first
        
        if let device = preferredDevice {
            print("Auto-selecting default preferred device: \(device.localizedName)")
            setPreferredDevice(device)
        }
    }
    
    // MARK: - Device Preference Management
    
    private func loadPreferredDevice() {
        preferredDeviceID = UserDefaults.standard.string(forKey: "MicOnPreferredDeviceID")
        print("Loaded preferred device ID: \(preferredDeviceID ?? "none")")
    }
    
    private func savePreferredDevice(_ deviceID: String) {
        preferredDeviceID = deviceID
        UserDefaults.standard.set(deviceID, forKey: "MicOnPreferredDeviceID")
        print("Saved preferred device ID: \(deviceID)")
    }
    
    func setPreferredDevice(_ device: AVCaptureDevice) {
        selectedDevice = device
        savePreferredDevice(device.uniqueID)
        currentlyUsingFallback = false
        
        // If microphone is active, restart with the new preferred device
        if isMicrophoneActive {
            print("Switching to new preferred device: \(device.localizedName)")
            attemptReconnection()
        }
    }
    
    private func getPreferredDevice() -> AVCaptureDevice? {
        guard let preferredID = preferredDeviceID else { return nil }
        return availableDevices.first { $0.uniqueID == preferredID }
    }
    
    private func setupDeviceChangeNotifications() {
        // Listen for device connection/disconnection events
        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasConnected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let device = notification.object as? AVCaptureDevice,
               device.hasMediaType(.audio) {
                print("Audio device connected: \(device.localizedName)")
                self?.refreshDevices()
                
                // Check if this is our preferred device coming back online
                if let preferredID = self?.preferredDeviceID,
                   device.uniqueID == preferredID {
                    print("🎯 Preferred device reconnected! Switching back to: \(device.localizedName)")
                    self?.currentlyUsingFallback = false
                    
                    // Switch back to preferred device immediately
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.attemptReconnection()
                    }
                } else if self?.isMicrophoneActive == true && self?.isMicrophoneReallyActive() == false {
                    // General reconnection attempt if we're supposed to be active but aren't
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.attemptReconnection()
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let device = notification.object as? AVCaptureDevice,
               device.hasMediaType(.audio) {
                print("Audio device disconnected: \(device.localizedName)")
                self?.refreshDevices()
                
                // Check if this was our preferred device
                if let preferredID = self?.preferredDeviceID,
                   device.uniqueID == preferredID {
                    print("⚠️ Preferred device disconnected: \(device.localizedName)")
                    self?.currentlyUsingFallback = true
                    
                    // Try to fall back to another device temporarily
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if self?.isMicrophoneActive == true {
                            self?.attemptReconnection()
                        }
                    }
                } else if device.uniqueID == self?.selectedDevice?.uniqueID {
                    print("Currently used device was disconnected!")
                    // Give it a moment for potential reconnection, then check state
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if self?.isMicrophoneActive == true {
                            self?.checkMicrophoneState()
                        }
                    }
                }
            }
        }
    }
    
    func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            // Already authorized
            print("Microphone access already authorized")
            break
        case .notDetermined:
            // Request permission - this will show the system dialog
            print("Requesting microphone permission...")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("Microphone permission granted")
                } else {
                    print("Microphone permission denied by user")
                    DispatchQueue.main.async {
                        self.showPermissionAlert()
                    }
                }
            }
        case .denied, .restricted:
            print("Microphone permission denied or restricted")
            DispatchQueue.main.async {
                self.showPermissionAlert()
            }
        @unknown default:
            break
        }
    }
    
    private func showPermissionAlert() {
        // Only show alert if permission is actually denied
        guard AVCaptureDevice.authorizationStatus(for: .audio) != .authorized else {
            print("Permission is already granted, not showing alert")
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Microphone Access Required"
        alert.informativeText = "MicOn needs microphone access to keep your Bluetooth headset connected.\n\nPlease grant permission in System Settings > Privacy & Security > Microphone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    func startMicrophone() {
        guard !isMicrophoneActive else { return }
        
        // Check permission first
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        print("Current authorization status: \(authStatus.rawValue)")
        
        guard authStatus == .authorized else {
            print("Cannot start microphone - permission not granted (status: \(authStatus.rawValue))")
            requestMicrophonePermission()
            return
        }
        
        print("Permission is authorized, starting microphone...")
        startMicrophoneInternal()
    }
    
    private func tryAudioEngineApproach() {
        tryAudioEngineApproachInternal()
    }
    
    private func resetCaptureSession() {
        captureSession?.stopRunning()
        captureSession = nil
    }
    
    private func resetAudioEngine() {
        if let input = audioEngine?.inputNode {
            input.removeTap(onBus: 0)
        }
        mixerNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine?.reset()
        audioEngine = nil
        inputNode = nil
        mixerNode = nil
    }
    
    func stopMicrophone() {
        guard isMicrophoneActive else { return }
        
        // Stop polling timer
        stopPollingTimer()
        
        // Stop capture session if it's being used
        resetCaptureSession()
        
        // Stop audio engine if it's being used
        resetAudioEngine()
        
        DispatchQueue.main.async {
            self.isMicrophoneActive = false
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.updateStatusIcon(isActive: false)
            }
        }
    }
    
    func toggleMicrophone() {
        if isMicrophoneActive {
            stopMicrophone()
            stopPollingTimer()
        } else {
            startMicrophone()
            startPollingTimer()
        }
    }
    
    // MARK: - Polling and State Management
    
    private func startPollingTimer() {
        stopPollingTimer() // Ensure no duplicate timers
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkMicrophoneState()
        }
    }
    
    private func stopPollingTimer() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    private func checkMicrophoneState() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            // Lost permission, update state
            DispatchQueue.main.async {
                if self.isMicrophoneActive {
                    print("Lost microphone permission")
                    self.isMicrophoneActive = false
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.updateStatusIcon(isActive: false)
                    }
                }
            }
            return
        }
        
        // Refresh devices to detect changes
        let oldDeviceCount = availableDevices.count
        refreshDevices()
        
        if availableDevices.count != oldDeviceCount {
            print("Device count changed: \(oldDeviceCount) -> \(availableDevices.count)")
        }
        
        // Check if our preferred device is now available but we're using a fallback
        if currentlyUsingFallback,
           let preferredDevice = getPreferredDevice(),
           selectedDevice?.uniqueID != preferredDevice.uniqueID {
            print("🔄 Preferred device is available but we're using fallback. Switching back...")
            DispatchQueue.main.async {
                self.attemptReconnection()
            }
            return
        }
        
        // Check if our selected device is still available
        let selectedDeviceAvailable = selectedDevice == nil || availableDevices.contains { $0.uniqueID == selectedDevice?.uniqueID }
        
        let actuallyActive = isMicrophoneReallyActive()
        let shouldBeActive = isMicrophoneActive
        
        print("State check - Should be active: \(shouldBeActive), Actually active: \(actuallyActive), Selected device available: \(selectedDeviceAvailable), Using fallback: \(currentlyUsingFallback)")
        
        DispatchQueue.main.async {
            if shouldBeActive {
                if !actuallyActive || !selectedDeviceAvailable {
                    print("Microphone should be active but isn't working properly. Attempting reconnection...")
                    // Force reconnection
                    self.isMicrophoneActive = false
                    self.attemptReconnection()
                } else {
                    // Everything looks good, but let's verify we have recent audio activity
                    if let lastInput = self.lastAudioInputTime,
                       Date().timeIntervalSince(lastInput) > 30 {
                        print("No recent audio input detected, forcing reconnection")
                        self.attemptReconnection()
                    }
                }
            } else if actuallyActive {
                // Microphone is running but UI shows inactive - sync state
                print("Microphone is running but UI shows inactive - syncing state")
                self.isMicrophoneActive = true
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.updateStatusIcon(isActive: true)
                }
            }
        }
    }
    
    private func isMicrophoneReallyActive() -> Bool {
        // Check if capture session is running and device is still connected
        if let captureSession = captureSession {
            let isRunning = captureSession.isRunning
            
            // Additional check: verify the device is still in our available devices
            if let currentDevice = selectedDevice {
                let deviceStillAvailable = availableDevices.contains { $0.uniqueID == currentDevice.uniqueID }
                return isRunning && deviceStillAvailable
            }
            
            return isRunning
        }
        
        // Check if audio engine is running
        if let audioEngine = audioEngine {
            return audioEngine.isRunning
        }
        
        return false
    }
    
    private func attemptReconnection() {
        print("Starting reconnection attempt...")
        
        // Clean up current state
        resetCaptureSession()
        resetAudioEngine()
        
        // Refresh available devices in case something changed
        refreshDevices()
        
        print("Available devices after refresh: \(availableDevices.map { $0.localizedName })")
        
        // Try to find the best device to use based on preference priority
        var deviceToUse: AVCaptureDevice?
        
        // HIGHEST PRIORITY: Preferred device if it's available
        if let preferredDevice = getPreferredDevice() {
            deviceToUse = preferredDevice
            currentlyUsingFallback = false
            print("✅ Using preferred device: \(deviceToUse?.localizedName ?? "unknown")")
        }
        // FALLBACK 1: Last successful device if it's still available
        else if let lastDevice = lastSuccessfulDevice,
           availableDevices.contains(where: { $0.uniqueID == lastDevice.uniqueID }) {
            deviceToUse = availableDevices.first { $0.uniqueID == lastDevice.uniqueID }
            currentlyUsingFallback = (deviceToUse?.uniqueID != preferredDeviceID)
            print("📱 Using last successful device (fallback): \(deviceToUse?.localizedName ?? "unknown")")
        }
        // FALLBACK 2: Currently selected device if still available
        else if let selectedDevice = selectedDevice,
                availableDevices.contains(where: { $0.uniqueID == selectedDevice.uniqueID }) {
            deviceToUse = availableDevices.first { $0.uniqueID == selectedDevice.uniqueID }
            currentlyUsingFallback = (deviceToUse?.uniqueID != preferredDeviceID)
            print("🔄 Using previously selected device (fallback): \(deviceToUse?.localizedName ?? "unknown")")
        }
        // FALLBACK 3: Any external/Bluetooth device
        else if let externalDevice = availableDevices.first(where: { $0.deviceType == .externalUnknown }) {
            deviceToUse = externalDevice
            currentlyUsingFallback = true
            print("🎧 Using any external device (fallback): \(deviceToUse?.localizedName ?? "unknown")")
        }
        // FALLBACK 4: Built-in microphone
        else if let builtInDevice = availableDevices.first(where: { $0.deviceType == .builtInMicrophone }) {
            deviceToUse = builtInDevice
            currentlyUsingFallback = true
            print("🖥️ Falling back to built-in microphone: \(deviceToUse?.localizedName ?? "unknown")")
        }
        
        if let device = deviceToUse {
            selectedDevice = device
            
            if currentlyUsingFallback {
                print("⚠️ Using fallback device - will switch back to preferred device when available")
            }
            
            startMicrophoneInternal()
        } else {
            print("❌ No audio devices available for reconnection")
            currentlyUsingFallback = false
            DispatchQueue.main.async {
                self.isMicrophoneActive = false
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.updateStatusIcon(isActive: false)
                }
            }
        }
    }
    
    private func startMicrophoneInternal() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            print("Cannot start microphone - permission not granted")
            return
        }
        
        // Use AVCaptureSession which allows sharing with other apps
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return }
        
        // Use default preset for minimal resource usage
        captureSession.sessionPreset = .low
        
        // Get the selected device or default audio device
        guard let device = selectedDevice ?? AVCaptureDevice.default(for: .audio) else {
            print("No audio device found")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            // Configure the session to allow sharing
            captureSession.beginConfiguration()
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            // Add a null output to keep the session active without recording
            let output = AVCaptureAudioDataOutput()
            output.setSampleBufferDelegate(nil, queue: nil) // No delegate = no processing
            
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            }
            
            captureSession.commitConfiguration()
            
            // Start the session on a background queue to avoid blocking
            DispatchQueue.global(qos: .background).async { [weak self] in
                captureSession.startRunning()
                
                DispatchQueue.main.async {
                    self?.isMicrophoneActive = true
                    self?.lastSuccessfulDevice = device
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.updateStatusIcon(isActive: true)
                    }
                    print("Microphone activated successfully: \(device.localizedName)")
                }
            }
        } catch {
            print("Failed to start microphone with AVCaptureSession: \(error)")
            // Try the audio engine approach as fallback
            tryAudioEngineApproachInternal()
        }
    }
    
    private func tryAudioEngineApproachInternal() {
        // Fallback to AVAudioEngine with minimal configuration
        resetCaptureSession()
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        let input = audioEngine.inputNode
        
        // Use the input's native format to avoid format mismatch
        // Install tap with nil format to use the input node's format and monitor audio levels
        input.installTap(onBus: 0, bufferSize: 256, format: nil) { [weak self] buffer, time in
            // Monitor audio activity to detect if we're really getting input
            self?.lastAudioInputTime = Date()
            
            // Check if there's actual audio data
            let audioBufferList = buffer.audioBufferList
            let audioBuffer = audioBufferList.pointee.mBuffers
            
            if let data = audioBuffer.mData {
                let samples = data.bindMemory(to: Float.self, capacity: Int(audioBuffer.mDataByteSize) / MemoryLayout<Float>.size)
                var hasSignal = false
                
                for i in 0..<Int(buffer.frameLength) {
                    if abs(samples[i]) > 0.001 { // Very low threshold to detect any activity
                        hasSignal = true
                        break
                    }
                }
                
                DispatchQueue.main.async {
                    self?.hasRecentAudioInput = hasSignal
                }
            }
        }
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isMicrophoneActive = true
                if let device = self.selectedDevice {
                    self.lastSuccessfulDevice = device
                }
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.updateStatusIcon(isActive: true)
                }
                print("Microphone activated using AVAudioEngine")
            }
        } catch {
            print("Failed to start audio engine: \(error)")
            DispatchQueue.main.async {
                self.isMicrophoneActive = false
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.updateStatusIcon(isActive: false)
                }
            }
        }
    }
}