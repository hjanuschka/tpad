import Foundation
import Network

@MainActor
class NetworkClient: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var discoveredServices: [NWBrowser.Result] = []
    @Published var browserState: String = ""
    
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "tpad.client")
    
    func startSearching() {
        browser?.cancel()
        browser = nil
        
        connectionState = .searching
        discoveredServices = []
        browserState = "Starting browser..."
        
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_tpad._udp", domain: "local.")
        let params = NWParameters()
        params.includePeerToPeer = true
        
        browser = NWBrowser(for: descriptor, using: params)
        
        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.browserState = "Searching..."
                case .failed(let error):
                    self?.browserState = "Error: \(error.localizedDescription)"
                    self?.connectionState = .disconnected
                case .cancelled:
                    self?.browserState = "Cancelled"
                default:
                    break
                }
            }
        }
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                self?.discoveredServices = Array(results)
                self?.browserState = "Found \(results.count) Mac(s)"
            }
        }
        
        browser?.start(queue: queue)
    }
    
    func stopSearching() {
        browser?.cancel()
        browser = nil
        browserState = ""
    }
    
    func connect(to result: NWBrowser.Result) {
        stopSearching()
        connectionState = .connecting
        
        let params = NWParameters.udp
        params.includePeerToPeer = true
        connection = NWConnection(to: result.endpoint, using: params)
        
        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    if case .service(let name, _, _, _) = result.endpoint {
                        self?.connectionState = .connected(name)
                    } else {
                        self?.connectionState = .connected("Mac")
                    }
                case .failed(let error):
                    print("Connection failed: \(error)")
                    self?.connectionState = .disconnected
                case .cancelled:
                    self?.connectionState = .disconnected
                default:
                    break
                }
            }
        }
        
        connection?.start(queue: queue)
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
        connectionState = .disconnected
        discoveredServices = []
    }
    
    func send(_ message: MouseMessage) {
        guard let data = message.encode() else { return }
        
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
        })
    }
    
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

extension NWBrowser.Result {
    var serviceName: String {
        if case .service(let name, _, _, _) = endpoint {
            return name
        }
        return "Unknown"
    }
}
