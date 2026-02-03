import AppKit
import Foundation
import Network
import TPadShared
import CoreGraphics
import CoreBluetooth

// MARK: - Settings

class TPadSettings {
    static let shared = TPadSettings()
    
    @AppStorage("wifiEnabled") var wifiEnabled: Bool = true
    @AppStorage("bluetoothEnabled") var bluetoothEnabled: Bool = true
}

// Simple AppStorage implementation for command-line app
@propertyWrapper
struct AppStorage<T> {
    let key: String
    let defaultValue: T
    
    init(wrappedValue: T, _ key: String) {
        self.key = key
        self.defaultValue = wrappedValue
    }
    
    var wrappedValue: T {
        get {
            UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

// MARK: - Mouse Controller

class MouseController {
    static let shared = MouseController()
    
    var sensitivity: CGFloat = 2.0
    
    private var totalScreenBounds: CGRect {
        var minX: CGFloat = 0
        var minY: CGFloat = 0
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        
        for screen in NSScreen.screens {
            let frame = screen.frame
            minX = min(minX, frame.minX)
            minY = min(minY, frame.minY)
            maxX = max(maxX, frame.maxX)
            maxY = max(maxY, frame.maxY)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    func moveMouse(deltaX: CGFloat, deltaY: CGFloat) {
        guard let currentPos = CGEvent(source: nil)?.location else { return }
        
        let newX = currentPos.x + (deltaX * sensitivity)
        let newY = currentPos.y + (deltaY * sensitivity)
        
        let bounds = totalScreenBounds
        let clampedX = max(bounds.minX, min(newX, bounds.maxX - 1))
        let clampedY = max(bounds.minY, min(newY, bounds.maxY - 1))
        
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                mouseCursorPosition: CGPoint(x: clampedX, y: clampedY),
                                mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
    }
    
    func leftClick() {
        guard let pos = CGEvent(source: nil)?.location else { return }
        
        let downEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                mouseCursorPosition: pos, mouseButton: .left)
        let upEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                              mouseCursorPosition: pos, mouseButton: .left)
        
        downEvent?.post(tap: .cghidEventTap)
        upEvent?.post(tap: .cghidEventTap)
    }
    
    func rightClick() {
        guard let pos = CGEvent(source: nil)?.location else { return }
        
        let downEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown,
                                mouseCursorPosition: pos, mouseButton: .right)
        let upEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp,
                              mouseCursorPosition: pos, mouseButton: .right)
        
        downEvent?.post(tap: .cghidEventTap)
        upEvent?.post(tap: .cghidEventTap)
    }
    
    func scroll(deltaX: CGFloat, deltaY: CGFloat) {
        let scrollEvent = CGEvent(scrollWheelEvent2Source: nil,
                                  units: .pixel,
                                  wheelCount: 2,
                                  wheel1: Int32(-deltaY * 3),
                                  wheel2: Int32(-deltaX * 3),
                                  wheel3: 0)
        scrollEvent?.post(tap: .cghidEventTap)
    }
    
    func leftDown() {
        guard let pos = CGEvent(source: nil)?.location else { return }
        let downEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                                mouseCursorPosition: pos, mouseButton: .left)
        downEvent?.post(tap: .cghidEventTap)
    }
    
    func leftUp() {
        guard let pos = CGEvent(source: nil)?.location else { return }
        let upEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                              mouseCursorPosition: pos, mouseButton: .left)
        upEvent?.post(tap: .cghidEventTap)
    }
    
    func drag(deltaX: CGFloat, deltaY: CGFloat) {
        guard let currentPos = CGEvent(source: nil)?.location else { return }
        
        let newX = currentPos.x + (deltaX * sensitivity)
        let newY = currentPos.y + (deltaY * sensitivity)
        
        let bounds = totalScreenBounds
        let clampedX = max(bounds.minX, min(newX, bounds.maxX - 1))
        let clampedY = max(bounds.minY, min(newY, bounds.maxY - 1))
        
        let dragEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged,
                                mouseCursorPosition: CGPoint(x: clampedX, y: clampedY),
                                mouseButton: .left)
        dragEvent?.post(tap: .cghidEventTap)
    }
}

// MARK: - Message Handler Protocol

protocol MessageHandler {
    func handleMessage(_ message: MouseMessage)
}

class TPadMessageHandler: MessageHandler {
    private let mouse = MouseController.shared
    
    func handleMessage(_ message: MouseMessage) {
        let dx = CGFloat(message.deltaX)
        let dy = CGFloat(message.deltaY)
        
        switch message.type {
        case .move:
            mouse.moveMouse(deltaX: dx, deltaY: dy)
        case .leftClick:
            mouse.leftClick()
        case .rightClick:
            mouse.rightClick()
        case .scroll, .scrollStart, .scrollEnd:
            mouse.scroll(deltaX: dx, deltaY: dy)
        case .leftDown:
            mouse.leftDown()
        case .leftUp:
            mouse.leftUp()
        case .dragStart:
            mouse.leftDown()
        case .drag:
            mouse.drag(deltaX: dx, deltaY: dy)
        case .dragEnd:
            mouse.leftUp()
        case .setSensitivity:
            let newSensitivity = CGFloat(message.deltaX)
            mouse.sensitivity = newSensitivity
            print("Sensitivity: \(newSensitivity)x")
        }
    }
}

// MARK: - Connection Info

struct ClientConnection: Identifiable, Equatable {
    let id: String
    let type: String // "WiFi" or "Bluetooth"
    let connectedAt: Date
    
    static func == (lhs: ClientConnection, rhs: ClientConnection) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - UDP Network Server

class UDPServer {
    private var listener: NWListener?
    private var connections: [String: NWConnection] = [:]
    private let queue = DispatchQueue(label: "tpad.udp.server")
    private let messageHandler: MessageHandler
    private var serviceName: String = ""
    
    var onClientConnected: ((String) -> Void)?
    var onClientDisconnected: ((String) -> Void)?
    var isRunning: Bool { listener != nil }
    
    init(messageHandler: MessageHandler) {
        self.messageHandler = messageHandler
    }
    
    func start() {
        guard listener == nil else { return }
        
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        
        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: TPadConfig.defaultPort))
        } catch {
            print("[UDP] Failed to create listener: \(error)")
            return
        }
        
        serviceName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        listener?.service = NWListener.Service(
            name: serviceName,
            type: TPadConfig.serviceType
        )
        
        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[UDP] Server ready on port \(TPadConfig.defaultPort)")
            case .failed(let error):
                print("[UDP] Server failed: \(error)")
            case .cancelled:
                print("[UDP] Server stopped")
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.start(queue: queue)
    }
    
    func stop() {
        for (_, connection) in connections {
            connection.cancel()
        }
        connections.removeAll()
        listener?.cancel()
        listener = nil
    }
    
    func disconnectAll() {
        for (id, connection) in connections {
            connection.cancel()
            onClientDisconnected?(id)
        }
        connections.removeAll()
    }
    
    private func handleConnection(_ connection: NWConnection) {
        let connectionId = UUID().uuidString
        connections[connectionId] = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.onClientConnected?(connectionId)
            case .failed, .cancelled:
                self?.connections.removeValue(forKey: connectionId)
                self?.onClientDisconnected?(connectionId)
            default:
                break
            }
        }
        
        connection.start(queue: queue)
        receiveMessage(on: connection, id: connectionId)
    }
    
    private func receiveMessage(on connection: NWConnection, id: String) {
        connection.receiveMessage { [weak self] data, _, isComplete, error in
            if let data = data, let message = MouseMessage.decode(from: data) {
                self?.messageHandler.handleMessage(message)
            }
            
            if let error = error {
                print("[UDP] Receive error: \(error)")
                return
            }
            
            self?.receiveMessage(on: connection, id: id)
        }
    }
}

// MARK: - Bluetooth Server

class BluetoothServer: NSObject, CBPeripheralManagerDelegate {
    private var peripheralManager: CBPeripheralManager!
    private var characteristic: CBMutableCharacteristic!
    private let messageHandler: MessageHandler
    private let queue = DispatchQueue(label: "tpad.bluetooth.server")
    private var serviceName: String = ""
    private var connectedCentrals: [String: CBCentral] = [:]
    
    var onClientConnected: ((String) -> Void)?
    var onClientDisconnected: ((String) -> Void)?
    var isRunning: Bool = false
    var isPoweredOn: Bool { peripheralManager?.state == .poweredOn }
    
    init(messageHandler: MessageHandler) {
        self.messageHandler = messageHandler
        super.init()
        serviceName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }
    
    func start() {
        guard !isRunning else { return }
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: queue)
        } else if isPoweredOn {
            setupService()
        }
        isRunning = true
    }
    
    func stop() {
        isRunning = false
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        connectedCentrals.removeAll()
    }
    
    func disconnectAll() {
        // BLE doesn't allow server to disconnect clients directly,
        // but we can stop advertising and remove service
        for (id, _) in connectedCentrals {
            onClientDisconnected?(id)
        }
        connectedCentrals.removeAll()
        
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        
        // Restart if still enabled
        if isRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.setupService()
            }
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            if isRunning {
                setupService()
            }
        case .poweredOff:
            print("[BT] Bluetooth is off")
        case .unauthorized:
            print("[BT] Bluetooth unauthorized")
        case .unsupported:
            print("[BT] Bluetooth unsupported")
        default:
            break
        }
    }
    
    private func setupService() {
        let serviceUUID = CBUUID(string: TPadConfig.bluetoothServiceUUID)
        let characteristicUUID = CBUUID(string: TPadConfig.bluetoothCharacteristicUUID)
        
        characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [characteristic]
        
        peripheralManager.add(service)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            print("[BT] Failed to add service: \(error)")
            return
        }
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: TPadConfig.bluetoothServiceUUID)],
            CBAdvertisementDataLocalNameKey: "T-Pad: \(serviceName)"
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        print("[BT] Server ready, advertising as 'T-Pad: \(serviceName)'")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        let id = central.identifier.uuidString
        connectedCentrals[id] = central
        print("[BT] Client connected: \(id)")
        DispatchQueue.main.async {
            self.onClientConnected?(id)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        let id = central.identifier.uuidString
        connectedCentrals.removeValue(forKey: id)
        print("[BT] Client disconnected: \(id)")
        DispatchQueue.main.async {
            self.onClientDisconnected?(id)
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let data = request.value {
                if let message = MouseMessage.decode(from: data) {
                    messageHandler.handleMessage(message)
                }
            }
            
            if request.characteristic.properties.contains(.write) {
                peripheralManager.respond(to: request, withResult: .success)
            }
        }
    }
}

// MARK: - Combined Server

class TPadServer {
    private let messageHandler = TPadMessageHandler()
    var udpServer: UDPServer!
    var bluetoothServer: BluetoothServer!
    private var serviceName: String
    
    private(set) var wifiConnections: [ClientConnection] = []
    private(set) var bluetoothConnections: [ClientConnection] = []
    
    var totalConnections: Int { wifiConnections.count + bluetoothConnections.count }
    var onConnectionsChanged: (() -> Void)?
    
    init() {
        serviceName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        
        udpServer = UDPServer(messageHandler: messageHandler)
        bluetoothServer = BluetoothServer(messageHandler: messageHandler)
        
        udpServer.onClientConnected = { [weak self] id in
            let conn = ClientConnection(id: id, type: "WiFi", connectedAt: Date())
            self?.wifiConnections.append(conn)
            print("iPhone connected via WiFi")
            DispatchQueue.main.async { self?.onConnectionsChanged?() }
        }
        udpServer.onClientDisconnected = { [weak self] id in
            self?.wifiConnections.removeAll { $0.id == id }
            print("iPhone disconnected (WiFi)")
            DispatchQueue.main.async { self?.onConnectionsChanged?() }
        }
        
        bluetoothServer.onClientConnected = { [weak self] id in
            let conn = ClientConnection(id: id, type: "Bluetooth", connectedAt: Date())
            self?.bluetoothConnections.append(conn)
            print("iPhone connected via Bluetooth")
            DispatchQueue.main.async { self?.onConnectionsChanged?() }
        }
        bluetoothServer.onClientDisconnected = { [weak self] id in
            self?.bluetoothConnections.removeAll { $0.id == id }
            print("iPhone disconnected (Bluetooth)")
            DispatchQueue.main.async { self?.onConnectionsChanged?() }
        }
    }
    
    func start() {
        print("T-Pad Server starting...")
        print("  Name: \(serviceName)")
        print("  Displays: \(NSScreen.screens.count)")
        print("")
        
        if TPadSettings.shared.wifiEnabled {
            udpServer.start()
        }
        if TPadSettings.shared.bluetoothEnabled {
            bluetoothServer.start()
        }
    }
    
    func stop() {
        udpServer.stop()
        bluetoothServer.stop()
    }
    
    func setWiFiEnabled(_ enabled: Bool) {
        TPadSettings.shared.wifiEnabled = enabled
        if enabled {
            udpServer.start()
        } else {
            udpServer.stop()
            wifiConnections.removeAll()
            onConnectionsChanged?()
        }
    }
    
    func setBluetoothEnabled(_ enabled: Bool) {
        TPadSettings.shared.bluetoothEnabled = enabled
        if enabled {
            bluetoothServer.start()
        } else {
            bluetoothServer.stop()
            bluetoothConnections.removeAll()
            onConnectionsChanged?()
        }
    }
    
    func disconnectAll() {
        udpServer.disconnectAll()
        bluetoothServer.disconnectAll()
        wifiConnections.removeAll()
        bluetoothConnections.removeAll()
        onConnectionsChanged?()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var server: TPadServer!
    
    // Menu items we need to update
    private var connectionStatusItem: NSMenuItem!
    private var wifiToggleItem: NSMenuItem!
    private var bluetoothToggleItem: NSMenuItem!
    private var disconnectAllItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibilityPermissions()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon(connected: false)
        
        buildMenu()
        
        server = TPadServer()
        server.onConnectionsChanged = { [weak self] in
            self?.updateMenu()
        }
        server.start()
    }
    
    private func updateStatusIcon(connected: Bool, count: Int = 0) {
        if let button = statusItem.button {
            if connected {
                // Red icon when connected
                let image = NSImage(systemSymbolName: "hand.point.up.fill", accessibilityDescription: "T-Pad")
                image?.isTemplate = false
                let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
                button.image = image?.withSymbolConfiguration(config)
            } else {
                // Normal icon when not connected
                button.image = NSImage(systemSymbolName: "hand.point.up.fill", accessibilityDescription: "T-Pad")
            }
        }
    }
    
    private func buildMenu() {
        let menu = NSMenu()
        
        // Title
        let titleItem = NSMenuItem(title: "T-Pad Server", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Connection status
        connectionStatusItem = NSMenuItem(title: "⚪ No connections", action: nil, keyEquivalent: "")
        connectionStatusItem.isEnabled = false
        menu.addItem(connectionStatusItem)
        
        // Disconnect all
        disconnectAllItem = NSMenuItem(title: "Disconnect All", action: #selector(disconnectAll), keyEquivalent: "d")
        disconnectAllItem.target = self
        disconnectAllItem.isEnabled = false
        menu.addItem(disconnectAllItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings header
        let settingsHeader = NSMenuItem(title: "Connection Types", action: nil, keyEquivalent: "")
        settingsHeader.isEnabled = false
        menu.addItem(settingsHeader)
        
        // WiFi toggle
        wifiToggleItem = NSMenuItem(title: "WiFi (Port \(TPadConfig.defaultPort))", action: #selector(toggleWiFi), keyEquivalent: "")
        wifiToggleItem.target = self
        wifiToggleItem.state = TPadSettings.shared.wifiEnabled ? .on : .off
        menu.addItem(wifiToggleItem)
        
        // Bluetooth toggle
        bluetoothToggleItem = NSMenuItem(title: "Bluetooth", action: #selector(toggleBluetooth), keyEquivalent: "")
        bluetoothToggleItem.target = self
        bluetoothToggleItem.state = TPadSettings.shared.bluetoothEnabled ? .on : .off
        menu.addItem(bluetoothToggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Info
        menu.addItem(NSMenuItem(title: "Displays: \(NSScreen.screens.count)", action: nil, keyEquivalent: ""))
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    private func updateMenu() {
        let total = server.totalConnections
        let wifiCount = server.wifiConnections.count
        let btCount = server.bluetoothConnections.count
        
        // Update icon
        updateStatusIcon(connected: total > 0, count: total)
        
        // Update connection status text
        if total == 0 {
            connectionStatusItem.title = "⚪ No connections"
        } else if total == 1 {
            let type = wifiCount > 0 ? "WiFi" : "Bluetooth"
            connectionStatusItem.title = "🔴 1 connection (\(type))"
        } else {
            var parts: [String] = []
            if wifiCount > 0 { parts.append("\(wifiCount) WiFi") }
            if btCount > 0 { parts.append("\(btCount) BT") }
            connectionStatusItem.title = "🔴 \(total) connections (\(parts.joined(separator: ", ")))"
        }
        
        // Enable/disable disconnect all
        disconnectAllItem.isEnabled = total > 0
    }
    
    @objc func toggleWiFi() {
        let newState = !TPadSettings.shared.wifiEnabled
        server.setWiFiEnabled(newState)
        wifiToggleItem.state = newState ? .on : .off
    }
    
    @objc func toggleBluetooth() {
        let newState = !TPadSettings.shared.bluetoothEnabled
        server.setBluetoothEnabled(newState)
        bluetoothToggleItem.state = newState ? .on : .off
    }
    
    @objc func disconnectAll() {
        server.disconnectAll()
    }
    
    func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !trusted {
            print("Accessibility permissions required")
            print("  Go to: System Settings > Privacy & Security > Accessibility")
        }
    }
    
    @objc func quit() {
        server.stop()
        NSApp.terminate(nil)
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
