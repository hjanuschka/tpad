import SwiftUI

struct TrackpadView: UIViewRepresentable {
    let client: NetworkClient
    
    func makeUIView(context: Context) -> TrackpadUIView {
        let view = TrackpadUIView(client: client)
        view.isMultipleTouchEnabled = true
        return view
    }
    
    func updateUIView(_ uiView: TrackpadUIView, context: Context) {}
}

class TrackpadUIView: UIView {
    let client: NetworkClient
    
    private var lastSingleTouch: CGPoint?
    private var lastTwoFingerCenter: CGPoint?
    private var touchStartTime: Date?
    private var lastTapTime: Date?
    private var lastTapPosition: CGPoint?
    private var touchStartPosition: CGPoint?
    private var initialTouchCount = 0
    private var hasMoved = false
    private var isDragging = false
    private var dragCheckTimer: Timer?
    
    private let tapMovementThreshold: CGFloat = 10.0
    private let tapTimeThreshold: TimeInterval = 0.22
    private let doubleTapTimeThreshold: TimeInterval = 0.35
    private let doubleTapDistanceThreshold: CGFloat = 50.0
    private let dragHoldTime: TimeInterval = 0.15
    
    init(client: NetworkClient) {
        self.client = client
        super.init(frame: .zero)
        self.isMultipleTouchEnabled = true
        self.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        self.layer.cornerRadius = 16
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allTouches = event?.allTouches ?? touches
        let now = Date()
        
        dragCheckTimer?.invalidate()
        dragCheckTimer = nil
        
        initialTouchCount = allTouches.count
        hasMoved = false
        touchStartTime = now
        
        if allTouches.count == 1 {
            let touch = allTouches.first!
            let pos = touch.location(in: self)
            lastSingleTouch = pos
            touchStartPosition = pos
            
            dragCheckTimer = Timer.scheduledTimer(withTimeInterval: dragHoldTime, repeats: false) { [weak self] _ in
                guard let self = self, !self.hasMoved, self.initialTouchCount == 1 else { return }
                self.isDragging = true
                self.client.sendDragStart()
                self.provideTapFeedback(style: .medium)
            }
            
        } else if allTouches.count == 2 {
            dragCheckTimer?.invalidate()
            dragCheckTimer = nil
            
            if isDragging {
                client.sendDragEnd()
                isDragging = false
            }
            
            let touchArray = Array(allTouches)
            let p1 = touchArray[0].location(in: self)
            let p2 = touchArray[1].location(in: self)
            lastTwoFingerCenter = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
            touchStartPosition = lastTwoFingerCenter
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allTouches = event?.allTouches ?? touches
        
        if allTouches.count == 2 {
            let touchArray = Array(allTouches)
            let p1 = touchArray[0].location(in: self)
            let p2 = touchArray[1].location(in: self)
            let center = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
            
            if let lastCenter = lastTwoFingerCenter {
                let deltaX = Float(center.x - lastCenter.x)
                let deltaY = Float(center.y - lastCenter.y)
                
                if let startPos = touchStartPosition {
                    let totalMovement = sqrt(pow(center.x - startPos.x, 2) + pow(center.y - startPos.y, 2))
                    if totalMovement > tapMovementThreshold {
                        hasMoved = true
                    }
                }
                
                if hasMoved {
                    client.sendScroll(deltaX: deltaX, deltaY: deltaY)
                }
            }
            lastTwoFingerCenter = center
            
        } else if allTouches.count == 1 {
            let touch = allTouches.first!
            let currentPos = touch.location(in: self)
            
            if let last = lastSingleTouch {
                let deltaX = Float(currentPos.x - last.x)
                let deltaY = Float(currentPos.y - last.y)
                
                if let startPos = touchStartPosition {
                    let totalMovement = sqrt(pow(currentPos.x - startPos.x, 2) + pow(currentPos.y - startPos.y, 2))
                    if totalMovement > tapMovementThreshold {
                        hasMoved = true
                        if !isDragging {
                            dragCheckTimer?.invalidate()
                            dragCheckTimer = nil
                        }
                    }
                }
                
                if isDragging {
                    client.sendDrag(deltaX: deltaX, deltaY: deltaY)
                } else {
                    client.sendMove(deltaX: deltaX, deltaY: deltaY)
                }
            }
            lastSingleTouch = currentPos
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragCheckTimer?.invalidate()
        dragCheckTimer = nil
        
        let allTouches = event?.allTouches ?? touches
        
        if isDragging {
            client.sendDragEnd()
            provideTapFeedback(style: .light)
            isDragging = false
            lastTapTime = nil
            lastTapPosition = nil
            resetState()
            return
        }
        
        guard let startTime = touchStartTime else {
            resetState()
            return
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let isTap = duration < tapTimeThreshold && !hasMoved
        
        if isTap {
            let now = Date()
            
            if initialTouchCount == 2 {
                client.sendRightClick()
                provideTapFeedback(style: .medium)
                lastTapTime = nil
                lastTapPosition = nil
            } else if initialTouchCount == 1 {
                var isDoubleTap = false
                if let lastTap = lastTapTime,
                   let lastPos = lastTapPosition,
                   let currentPos = touchStartPosition {
                    let timeSinceLastTap = now.timeIntervalSince(lastTap)
                    let distanceFromLastTap = sqrt(pow(currentPos.x - lastPos.x, 2) + pow(currentPos.y - lastPos.y, 2))
                    isDoubleTap = timeSinceLastTap < doubleTapTimeThreshold && distanceFromLastTap < doubleTapDistanceThreshold
                }
                
                if isDoubleTap {
                    client.sendLeftClick()
                    client.sendLeftClick()
                    provideTapFeedback(style: .heavy)
                    lastTapTime = nil
                    lastTapPosition = nil
                } else {
                    client.sendLeftClick()
                    provideTapFeedback(style: .light)
                    lastTapTime = now
                    lastTapPosition = touchStartPosition
                }
            }
        } else {
            lastTapTime = nil
            lastTapPosition = nil
        }
        
        resetState()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragCheckTimer?.invalidate()
        dragCheckTimer = nil
        
        if isDragging {
            client.sendDragEnd()
            isDragging = false
        }
        resetState()
    }
    
    private func resetState() {
        lastSingleTouch = nil
        lastTwoFingerCenter = nil
        touchStartTime = nil
        touchStartPosition = nil
        initialTouchCount = 0
        hasMoved = false
    }
    
    private func provideTapFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
