import Foundation

// MARK: - Network Configuration

public enum TPadConfig {
    public static let serviceType = "_tpad._udp"
    public static let serviceDomain = "local."
    public static let defaultPort: UInt16 = 5679
    
    // Bluetooth UUIDs
    public static let bluetoothServiceUUID = "B5E6D143-7A8E-4F3C-9D2A-1E8C4F5A6B7D"
    public static let bluetoothCharacteristicUUID = "C8F2E951-3B4D-4A6E-8C1F-2D9E5A7B3C8F"
}

// MARK: - Message Types

public enum MessageType: UInt8, Codable {
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

public struct MouseMessage: Codable {
    public let type: MessageType
    public let deltaX: Float
    public let deltaY: Float
    public let timestamp: UInt64
    
    public init(type: MessageType, deltaX: Float = 0, deltaY: Float = 0) {
        self.type = type
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
    }
    
    public func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    public static func decode(from data: Data) -> MouseMessage? {
        try? JSONDecoder().decode(MouseMessage.self, from: data)
    }
}
