import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    @State private var showDeviceMenu = false
    
    private var preferredDeviceName: String {
        if let preferredID = appState.preferredDeviceID,
           let device = appState.availableDevices.first(where: { $0.uniqueID == preferredID }) {
            return device.localizedName
        }
        return "Select Device"
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 25) {
                // Title with more padding
                Text("MicOn")
                    .font(.system(size: 26, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .tracking(0.5)
                    .padding(.top, 95)
                
                Spacer()
                
                // Microphone Button with fixed size container
                VStack(spacing: 20) {
                    ZStack {
                        // Invisible frame to maintain consistent size
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 140, height: 140)
                        
                        // Background circle for active state only
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .scaleEffect(isHovering ? 1.15 : 1.0)
                            .opacity(appState.isMicrophoneActive ? 1 : 0)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        appState.isMicrophoneActive ? Color.green : Color.red.opacity(0.8),
                                        appState.isMicrophoneActive ? Color.green.opacity(0.6) : Color.red.opacity(0.4)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)
                            .shadow(color: appState.isMicrophoneActive ? .green.opacity(0.5) : .red.opacity(0.3), radius: isHovering ? 20 : 12)
                            .scaleEffect(isHovering ? 1.1 : 1.0)
                        
                        Button(action: {
                            appState.toggleMicrophone()
                        }) {
                            Image(systemName: appState.isMicrophoneActive ? "mic.fill" : "mic.slash.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isHovering = hovering
                            }
                        }
                    }
                    .frame(width: 140, height: 140) // Fixed container size
                    
                    VStack(spacing: 4) {
                        Text(appState.isMicrophoneActive ? "Microphone Active" : "Microphone Inactive")
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.85))
                            .tracking(0.3)
                        
                        Text("No audio is being recorded or saved")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.2)
                        
                        // Show permission button if not authorized
                        if AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
                            Button(action: {
                                appState.requestMicrophonePermission()
                            }) {
                                Text("Grant Microphone Access")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.blue.opacity(0.6))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 8)
                        }
                    }
                }
                
                Spacer()
                
                // Device Selector with more padding
                if !appState.availableDevices.isEmpty {
                    VStack(spacing: 10) {
                        Text("AUDIO DEVICE")
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.2)
                        
                        ZStack(alignment: .top) {
                            // Custom dropdown button
                            Button(action: {
                                showDeviceMenu.toggle()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 13))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(preferredDeviceName)
                                            .font(.system(size: 13, weight: .regular, design: .default))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        
                                        if appState.currentlyUsingFallback {
                                            Text("Using: \(appState.selectedDevice?.localizedName ?? "Unknown")")
                                                .font(.system(size: 10, weight: .regular))
                                                .foregroundColor(.orange.opacity(0.8))
                                                .lineLimit(1)
                                        }
                                    }
                                    Image(systemName: showDeviceMenu ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(.white.opacity(0.95))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                                .frame(width: 280)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .frame(width: 280, height: 40)
                        .overlay(
                            // Custom dropdown menu as overlay
                            Group {
                                if showDeviceMenu {
                                    VStack(spacing: 0) {
                                        ForEach(appState.availableDevices, id: \.uniqueID) { device in
                                            Button(action: {
                                                appState.setPreferredDevice(device)
                                                showDeviceMenu = false
                                            }) {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(device.localizedName)
                                                            .font(.system(size: 12, weight: .regular))
                                                            .lineLimit(1)
                                                        
                                                        if device.uniqueID == appState.preferredDeviceID {
                                                            Text("Preferred Device")
                                                                .font(.system(size: 10, weight: .medium))
                                                                .foregroundColor(.green.opacity(0.8))
                                                        }
                                                    }
                                                    Spacer()
                                                    HStack(spacing: 6) {
                                                        if device.uniqueID == appState.preferredDeviceID {
                                                            Image(systemName: "heart.fill")
                                                                .font(.system(size: 9))
                                                                .foregroundColor(.green)
                                                        }
                                                        if device == appState.selectedDevice {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 10))
                                                                .foregroundColor(.blue)
                                                        }
                                                    }
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .frame(maxWidth: .infinity)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .foregroundColor(.white.opacity(0.9))
                                            .background(
                                                device == appState.selectedDevice ?
                                                Color.white.opacity(0.1) : Color.clear
                                            )
                                            
                                            if device != appState.availableDevices.last {
                                                Divider()
                                                    .background(Color.white.opacity(0.1))
                                            }
                                        }
                                    }
                                    .frame(width: 280)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                            )
                                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                                    )
                                    .offset(y: 45)
                                    .zIndex(1000)
                                }
                            },
                            alignment: .top
                        )
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 195)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 400, height: 620)
        .onTapGesture {
            // Close dropdown when tapping outside
            if showDeviceMenu {
                showDeviceMenu = false
            }
        }
    }
}