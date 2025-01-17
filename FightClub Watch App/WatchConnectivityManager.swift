import WatchConnectivity
import Foundation

enum ConnectionState {
    case disconnected
    case connected
    case inactive
    case activating
    
    var isConnected: Bool {
        switch self {
        case .connected:
            return true
        case .disconnected, .inactive, .activating:
            return false
        }
    }
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var connectionState: ConnectionState = .disconnected
    @Published var workoutState: [String: Any] = [:]
    
    private var session: WCSession?
    private var lastMessageTime: Date?
    private let messageInterval: TimeInterval = 0.5
    
    private override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        if WCSession.isSupported() {
            print("WCSession is supported")
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            print("WCSession activation requested")
            
            // 초기 앱 컨텍스트 설정
            updateApplicationContext(["status": "initialized"])
        }
    }
    
    // MARK: - Application Context
    func updateApplicationContext(_ context: [String: Any]) {
        guard let session = session else { return }
        do {
            try session.updateApplicationContext(context)
            print("Application context updated: \(context)")
        } catch {
            print("Failed to update application context: \(error)")
        }
    }
    
    // MARK: - Message Sending
    func sendHeartRate(_ heartRate: Double) {
        guard canSendMessage() else { return }
        
        let message: [String: Any] = [
            "type": "healthData",
            "heartRate": heartRate,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
    
    func sendCalories(_ calories: Double) {
        guard canSendMessage() else { return }
        
        let message: [String: Any] = [
            "type": "healthData",
            "calories": calories,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
    
    func sendPunchData(speed: Double, isMax: Bool = false) {
        guard canSendMessage() else { return }
        
        let message: [String: Any] = [
            "type": "punchData",
            "speed": speed,
            "isMax": isMax,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
    
    func sendWorkoutStarted() {
        let message: [String: Any] = [
            "type": "workoutStatus",
            "status": "started",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
    
    func sendWorkoutEnded() {
        let message: [String: Any] = [
            "type": "workoutStatus",
            "status": "ended",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
    
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let session = session, session.isReachable else {
            print("Cannot send message - session not reachable")
            return
        }
        
        // 메시지에 타임스탬프 추가
        var messageWithTimestamp = message
        messageWithTimestamp["timestamp"] = Date().timeIntervalSince1970
        
        session.sendMessage(messageWithTimestamp, replyHandler: { reply in
            print("Message sent successfully: \(messageWithTimestamp)")
            replyHandler?(reply)
        }) { error in
            print("Failed to send message: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    private func canSendMessage() -> Bool {
        guard let session = session, session.isReachable else {
            return false
        }
        
        if let lastTime = lastMessageTime,
           Date().timeIntervalSince(lastTime) < messageInterval {
            return false
        }
        
        lastMessageTime = Date()
        return true
    }
    
    private func updateConnectionState() {
        guard let session = session else {
            connectionState = .disconnected
            return
        }
        
        DispatchQueue.main.async {
            switch session.activationState {
            case .notActivated:
                self.connectionState = .disconnected
            case .inactive:
                self.connectionState = .inactive
            case .activated:
                self.connectionState = session.isReachable ? .connected : .disconnected
            @unknown default:
                self.connectionState = .disconnected
            }
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            print("WCSession activation completed - state: \(activationState.rawValue)")
            if let error = error {
                print("WCSession activation error: \(error.localizedDescription)")
            }
            self.updateConnectionState()
            
            // 활성화 완료 후 초기 컨텍스트 설정
            if activationState == .activated {
                self.updateApplicationContext(["status": "ready"])
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            print("Received application context: \(applicationContext)")
            self.workoutState = applicationContext
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("WCSession reachability changed: \(session.isReachable)")
            self.updateConnectionState()
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
        DispatchQueue.main.async {
            self.connectionState = .inactive
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            // watchOS에서는 세션이 비활성화되면 다시 활성화
            session.activate()
        }
    }
} 