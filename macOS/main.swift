import AppKit
import Foundation
import Network
import TPadShared
import CoreGraphics

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

// MARK: - Network Server

class TPadServer {
    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "tpad.server")
    private let mouse = MouseController.shared
    private var serviceName: String = ""
    
    func start() {
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        
        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: TPadConfig.defaultPort))
        } catch {
            print("Failed to create listener: \(error)")
            return
        }
        
        serviceName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        listener?.service = NWListener.Service(
            name: serviceName,
            type: TPadConfig.serviceType
        )
        
        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("T-Pad Server ready")
                print("  Name: \(self?.serviceName ?? "T-Pad")")
                print("  Port: \(TPadConfig.defaultPort)")
                print("  Displays: \(NSScreen.screens.count)")
            case .failed(let error):
                print("Server failed: \(error)")
            case .cancelled:
                print("Server stopped")
            default:
                break
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            print("iPhone connected")
            self?.handleConnection(connection)
        }
        
        listener?.start(queue: queue)
    }
    
    private func handleConnection(_ connection: NWConnection) {
        self.connection = connection
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                break
            case .failed(let error):
                print("Connection failed: \(error)")
            case .cancelled:
                print("iPhone disconnected")
            default:
                break
            }
        }
        
        connection.start(queue: queue)
        receiveMessage(on: connection)
    }
    
    private func receiveMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, isComplete, error in
            if let data = data, let message = MouseMessage.decode(from: data) {
                self?.handleMessage(message)
            }
            
            if let error = error {
                print("Receive error: \(error)")
                return
            }
            
            self?.receiveMessage(on: connection)
        }
    }
    
    private func handleMessage(_ message: MouseMessage) {
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
    
    func stop() {
        listener?.cancel()
        connection?.cancel()
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var server: TPadServer!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibilityPermissions()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hand.point.up.fill", accessibilityDescription: "T-Pad")
            if button.image == nil {
                button.title = "T-Pad"
            }
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "T-Pad Server", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Displays: \(NSScreen.screens.count)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Port: \(TPadConfig.defaultPort)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        
        server = TPadServer()
        server.start()
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
