import SwiftUI
import AVFoundation
import AppKit

@main
struct MicOnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
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
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var captureSession: AVCaptureSession?
    private var mixerNode: AVAudioMixerNode?
    
    init() {
        refreshDevices()
        requestMicrophonePermission()
        
        // Start with microphone on by default after permissions are granted
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            // Only start if we have permission
            if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                self?.startMicrophone()
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
        
        if selectedDevice == nil, let first = availableDevices.first {
            selectedDevice = first
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
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.updateStatusIcon(isActive: true)
                    }
                    print("Microphone activated successfully (shared mode)")
                }
            }
        } catch {
            print("Failed to start microphone: \(error)")
            // Try the audio engine approach as fallback
            tryAudioEngineApproach()
        }
    }
    
    private func tryAudioEngineApproach() {
        // Fallback to AVAudioEngine with minimal configuration
        resetCaptureSession()
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        let input = audioEngine.inputNode
        
        // Use the input's native format to avoid format mismatch
        // Install tap with nil format to use the input node's format
        input.installTap(onBus: 0, bufferSize: 256, format: nil) { buffer, time in
            // Empty - just keep the mic active
        }
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isMicrophoneActive = true
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.updateStatusIcon(isActive: true)
                }
            }
            print("Microphone activated using AVAudioEngine (shared mode)")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
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
        } else {
            startMicrophone()
        }
    }
}