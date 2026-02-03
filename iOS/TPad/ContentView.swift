import SwiftUI

struct ContentView: View {
    @StateObject private var client = NetworkClient()
    @State private var showingServerPicker = false
    @State private var showingSettings = false
    @AppStorage("sensitivity") private var sensitivity: Double = 2.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                
                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                if case .connected = client.connectionState {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                    }
                }
                
                Button(action: {
                    if case .connected = client.connectionState {
                        client.disconnect()
                    } else {
                        client.startBrowsing()
                        showingServerPicker = true
                    }
                }) {
                    Text(buttonText)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.black)
            
            if case .connected = client.connectionState {
                TrackpadView(client: client)
                    .padding()
                    .background(Color.black)
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "hand.point.up.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("T-Pad")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    
                    Text("Use your iPhone as a trackpad")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Button(action: {
                        client.startBrowsing()
                        showingServerPicker = true
                    }) {
                        Label("Connect to Mac", systemImage: "laptopcomputer")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showingServerPicker) {
            ServerPickerView(client: client, isPresented: $showingServerPicker, sensitivity: sensitivity)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(client: client, sensitivity: $sensitivity)
        }
    }
    
    var statusColor: Color {
        switch client.connectionState {
        case .disconnected: return .red
        case .searching, .connecting: return .yellow
        case .connected: return .green
        }
    }
    
    var statusText: String {
        switch client.connectionState {
        case .disconnected: return "Disconnected"
        case .searching: return "Searching..."
        case .connecting: return "Connecting..."
        case .connected(let name, let type): return "\(name) (\(type.rawValue))"
        }
    }
    
    var buttonText: String {
        switch client.connectionState {
        case .disconnected: return "Connect"
        case .searching: return "Searching..."
        case .connecting: return "Connecting..."
        case .connected: return "Disconnect"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var client: NetworkClient
    @Binding var sensitivity: Double
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Cursor Speed")
                            Spacer()
                            Text(String(format: "%.1fx", sensitivity))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "tortoise")
                                .foregroundColor(.secondary)
                            Slider(value: $sensitivity, in: 0.5...5.0, step: 0.1) { editing in
                                if !editing {
                                    client.sendSensitivity(Float(sensitivity))
                                }
                            }
                            Image(systemName: "hare")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Speed")
                }
                
                Section {
                    GestureRow(gesture: "Tap", action: "Click")
                    GestureRow(gesture: "Double Tap", action: "Double Click")
                    GestureRow(gesture: "Two-Finger Tap", action: "Right Click")
                    GestureRow(gesture: "Two-Finger Drag", action: "Scroll")
                    GestureRow(gesture: "Tap, Hold & Drag", action: "Drag / Select")
                } header: {
                    Text("Gestures")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            client.sendSensitivity(Float(sensitivity))
        }
    }
}

struct GestureRow: View {
    let gesture: String
    let action: String
    
    var body: some View {
        HStack {
            Text(gesture)
            Spacer()
            Text(action)
                .foregroundColor(.secondary)
        }
    }
}

struct ServerPickerView: View {
    @ObservedObject var client: NetworkClient
    @Binding var isPresented: Bool
    var sensitivity: Double
    
    var body: some View {
        NavigationView {
            List {
                if client.discoveredServers.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Searching for Macs...")
                            .foregroundColor(.secondary)
                        Text("Make sure T-Pad server is running")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    // WiFi servers
                    let wifiServers = client.discoveredServers.filter { $0.type == .wifi }
                    if !wifiServers.isEmpty {
                        Section(header: Label("WiFi", systemImage: "wifi")) {
                            ForEach(wifiServers) { server in
                                ServerRow(server: server) {
                                    connectTo(server)
                                }
                            }
                        }
                    }
                    
                    // Bluetooth servers
                    let btServers = client.discoveredServers.filter { $0.type == .bluetooth }
                    if !btServers.isEmpty {
                        Section(header: Label("Bluetooth", systemImage: "bluetooth")) {
                            ForEach(btServers) { server in
                                ServerRow(server: server) {
                                    connectTo(server)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Mac")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        client.stopBrowsing()
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { client.startBrowsing() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if client.discoveredServers.isEmpty {
                client.startBrowsing()
            }
        }
    }
    
    private func connectTo(_ server: DiscoveredServer) {
        client.connect(to: server)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            client.sendSensitivity(Float(sensitivity))
        }
        isPresented = false
    }
}

struct ServerRow: View {
    let server: DiscoveredServer
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: server.type == .wifi ? "desktopcomputer" : "desktopcomputer")
                    .font(.title2)
                    .foregroundColor(server.type == .wifi ? .blue : .purple)
                    .frame(width: 40)
                
                VStack(alignment: .leading) {
                    Text(server.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(server.type == .wifi ? "WiFi Connection" : "Bluetooth Connection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    ContentView()
}
