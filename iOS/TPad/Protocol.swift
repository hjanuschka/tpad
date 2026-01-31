import Foundation

// MARK: - Network Configuration

enum TPadConfig {
    static let serviceType = "_tpad._udp"
    static let serviceDomain = "local."
    static let defaultPort: UInt16 = 5679
}

// MARK: - Message Types

enum MessageType: UInt8, Codable {
    case move = 1
    case leftClick = 2
    case rightClick = 3
    case scrollStart = 4
    case scroll = 5
    case scrollEnd = 6
    case leftDown = 7
    case leftUp = 8
    case dragStart = 9
    case drag = 10
    case dragEnd = 11
    case setSensitivity = 20
}

// MARK: - Mouse Event Message

struct MouseMessage: Codable {
    let type: MessageType
    let deltaX: Float
    let deltaY: Float
    let timestamp: UInt64
    
    init(type: MessageType, deltaX: Float = 0, deltaY: Float = 0) {
        self.type = type
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
    }
    
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> MouseMessage? {
        try? JSONDecoder().decode(MouseMessage.self, from: data)
    }
}

// MARK: - Connection State

enum ConnectionState: Equatable {
    case disconnected
    case searching
    case connecting
    case connected(String)
    
    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .searching: return "Searching..."
        case .connecting: return "Connecting..."
        case .connected(let host): return "Connected to \(host)"
        }
    }
}
