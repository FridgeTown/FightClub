import WatchConnectivity
import Foundation

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    enum ConnectionState {
        case connected
        case disconnected
        case inactive
        case notActivated
    }
    
    @Published var connectionState: ConnectionState = .inactive
    @Published var receivedMessage: [String: Any] = [:]
    
    override private init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    // MARK: - Message Sending
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard WCSession.default.isReachable else {
            print("Watch is not reachable")
            return
        }
        
        WCSession.default.sendMessage(message, replyHandler: replyHandler) { error in
            print("Failed to send message: \(error.localizedDescription)")
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("WCSession activation failed with error: \(error.localizedDescription)")
                return
            }
            
            switch activationState {
            case .activated:
                self.connectionState = .connected
            case .inactive:
                self.connectionState = .inactive
            case .notActivated:
                self.connectionState = .notActivated
            @unknown default:
                self.connectionState = .disconnected
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            if session.isReachable {
                self.connectionState = .connected
            } else {
                self.connectionState = .disconnected
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.receivedMessage = message
            NotificationCenter.default.post(name: .init("watchMessageReceived"), object: nil, userInfo: message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            self.receivedMessage = message
            NotificationCenter.default.post(name: .init("watchMessageReceived"), object: nil, userInfo: message)
            replyHandler(["status": "received"])
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.receivedMessage = applicationContext
            NotificationCenter.default.post(name: .init("watchContextReceived"), object: nil, userInfo: applicationContext)
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.connectionState = .inactive
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.connectionState = .notActivated
            // Reactivate the session
            session.activate()
        }
    }
    #endif
}

// MARK: - Notification Names
extension Notification.Name {
    static let watchMessageReceived = Notification.Name("watchMessageReceived")
    static let watchContextReceived = Notification.Name("watchContextReceived")
    static let watchConnectionStateChanged = Notification.Name("watchConnectionStateChanged")
} 
