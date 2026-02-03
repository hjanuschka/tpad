import Foundation
import Network
import CoreBluetooth

// MARK: - Bluetooth UUIDs (must match server)

enum TPadBluetooth {
    static let serviceUUID = CBUUID(string: "B5E6D143-7A8E-4F3C-9D2A-1E8C4F5A6B7D")
    static let characteristicUUID = CBUUID(string: "C8F2E951-3B4D-4A6E-8C1F-2D9E5A7B3C8F")
}

// MARK: - Discovered Server

struct DiscoveredServer: Identifiable, Hashable {
    let id: String
    let name: String
    let type: ConnectionType
    let endpoint: NWEndpoint?
    let peripheral: CBPeripheral?
    
    enum ConnectionType: String {
        case wifi = "WiFi"
        case bluetooth = "Bluetooth"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DiscoveredServer, rhs: DiscoveredServer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Connection State

enum ConnectionState: Equatable {
    case disconnected
    case searching
    case connecting
    case connected(String, DiscoveredServer.ConnectionType)
    
    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.searching, .searching),
             (.connecting, .connecting):
            return true
        case let (.connected(h1, t1), .connected(h2, t2)):
            return h1 == h2 && t1 == t2
        default:
            return false
        }
    }
}

// MARK: - Network Client

class NetworkClient: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var discoveredServers: [DiscoveredServer] = []
    
    // WiFi
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "tpad.client")
    
    // Bluetooth
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    
    private var currentServer: DiscoveredServer?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: queue)
    }
    
    // MARK: - Discovery
    
    func startBrowsing() {
        connectionState = .searching
        discoveredServers = []
        discoveredPeripherals = [:]
        
        // Start WiFi discovery
        startWiFiBrowsing()
        
        // Start Bluetooth discovery (if powered on)
        if centralManager.state == .poweredOn {
            startBluetoothScanning()
        }
    }
    
    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        centralManager.stopScan()
        
        if connectionState == .searching {
            connectionState = .disconnected
        }
    }
    
    // MARK: - WiFi Discovery
    
    private func startWiFiBrowsing() {
        let params = NWParameters()
        params.includePeerToPeer = true
        
        browser = NWBrowser(for: .bonjour(type: "_tpad._udp", domain: nil), using: params)
        
        browser?.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                print("[WiFi] Browser failed: \(error)")
            }
        }
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleWiFiResults(results)
        }
        
        browser?.start(queue: queue)
    }
    
    private func handleWiFiResults(_ results: Set<NWBrowser.Result>) {
        var wifiServers: [DiscoveredServer] = []
        
        for result in results {
            if case .service(let name, _, _, _) = result.endpoint {
                let server = DiscoveredServer(
                    id: "wifi-\(name)",
                    name: name,
                    type: .wifi,
                    endpoint: result.endpoint,
                    peripheral: nil
                )
                wifiServers.append(server)
            }
        }
        
        DispatchQueue.main.async {
            // Merge with Bluetooth servers
            let btServers = self.discoveredServers.filter { $0.type == .bluetooth }
            self.discoveredServers = wifiServers + btServers
        }
    }
    
    // MARK: - Bluetooth Discovery
    
    private func startBluetoothScanning() {
        centralManager.scanForPeripherals(
            withServices: [TPadBluetooth.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        print("[BT] Scanning for T-Pad servers...")
    }
    
    // MARK: - Connection
    
    func connect(to server: DiscoveredServer) {
        currentServer = server
        connectionState = .connecting
        stopBrowsing()
        
        switch server.type {
        case .wifi:
            connectWiFi(to: server)
        case .bluetooth:
            connectBluetooth(to: server)
        }
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        connectedPeripheral = nil
        writeCharacteristic = nil
        currentServer = nil
        
        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }
    
    // MARK: - WiFi Connection
    
    private func connectWiFi(to server: DiscoveredServer) {
        guard let endpoint = server.endpoint else { return }
        
        let params = NWParameters.udp
        connection = NWConnection(to: endpoint, using: params)
        
        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.connectionState = .connected(server.name, .wifi)
                case .failed, .cancelled:
                    self?.connectionState = .disconnected
                default:
                    break
                }
            }
        }
        
        connection?.start(queue: queue)
    }
    
    // MARK: - Bluetooth Connection
    
    private func connectBluetooth(to server: DiscoveredServer) {
        guard let peripheral = server.peripheral else { return }
        centralManager.connect(peripheral, options: nil)
    }
    
    // MARK: - Send Messages
    
    func send(_ message: MouseMessage) {
        guard let data = message.encode() else { return }
        
        if let connection = connection, connectionState != .disconnected {
            // WiFi
            connection.send(content: data, completion: .idempotent)
        } else if let peripheral = connectedPeripheral,
                  let characteristic = writeCharacteristic {
            // Bluetooth - use writeWithoutResponse for lower latency
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        }
    }
    
    // Convenience methods
    func sendMove(deltaX: Float, deltaY: Float) {
        send(MouseMessage(type: .move, deltaX: deltaX, deltaY: deltaY))
    }
    
    func sendLeftClick() {
        send(MouseMessage(type: .leftClick))
    }
    
    func sendRightClick() {
        send(MouseMessage(type: .rightClick))
    }
    
    func sendScroll(deltaX: Float, deltaY: Float) {
        send(MouseMessage(type: .scroll, deltaX: deltaX, deltaY: deltaY))
    }
    
    func sendDragStart() {
        send(MouseMessage(type: .dragStart))
    }
    
    func sendDrag(deltaX: Float, deltaY: Float) {
        send(MouseMessage(type: .drag, deltaX: deltaX, deltaY: deltaY))
    }
    
    func sendDragEnd() {
        send(MouseMessage(type: .dragEnd))
    }
    
    func sendSensitivity(_ value: Float) {
        send(MouseMessage(type: .setSensitivity, deltaX: value, deltaY: 0))
    }
}

// MARK: - CBCentralManagerDelegate

extension NetworkClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("[BT] Bluetooth ready")
            // If we're currently searching, start BT scan
            if connectionState == .searching {
                startBluetoothScanning()
            }
        case .poweredOff:
            print("[BT] Bluetooth is off")
        case .unauthorized:
            print("[BT] Bluetooth unauthorized")
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? peripheral.name
            ?? "Unknown Mac"
        
        // Store peripheral reference
        discoveredPeripherals[peripheral.identifier.uuidString] = peripheral
        
        let server = DiscoveredServer(
            id: "bt-\(peripheral.identifier.uuidString)",
            name: name.replacingOccurrences(of: "T-Pad: ", with: ""),
            type: .bluetooth,
            endpoint: nil,
            peripheral: peripheral
        )
        
        DispatchQueue.main.async {
            // Add if not already present
            if !self.discoveredServers.contains(where: { $0.id == server.id }) {
                self.discoveredServers.append(server)
                print("[BT] Found: \(name)")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[BT] Connected to \(peripheral.name ?? "Unknown")")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([TPadBluetooth.serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[BT] Failed to connect: \(error?.localizedDescription ?? "unknown")")
        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[BT] Disconnected")
        connectedPeripheral = nil
        writeCharacteristic = nil
        
        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
    }
}

// MARK: - CBPeripheralDelegate

extension NetworkClient: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == TPadBluetooth.serviceUUID {
                peripheral.discoverCharacteristics([TPadBluetooth.characteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == TPadBluetooth.characteristicUUID {
                writeCharacteristic = characteristic
                
                let serverName = currentServer?.name ?? peripheral.name ?? "Mac"
                DispatchQueue.main.async {
                    self.connectionState = .connected(serverName, .bluetooth)
                }
                print("[BT] Ready to send data")
            }
        }
    }
}
