import WatchConnectivity

class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()
    private var wcSession: WCSession?
    
    @Published var messageFromPhone: String = ""
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
            
            print("=== Watch 앱 WCSession 설정 ===")
            print("Watch 앱 번들 ID: \(Bundle.main.bundleIdentifier ?? "없음")")
        }
    }
    
    func sendMessageToPhone() {
        guard let session = wcSession, session.isReachable else {
            print("iPhone에 연결할 수 없습니다")
            return
        }
        
        session.sendMessage(["message": "Hello from Watch"], replyHandler: { reply in
            print("iPhone 응답: \(reply)")
        }, errorHandler: { error in
            print("메시지 전송 실패: \(error.localizedDescription)")
        })
    }
}

extension WorkoutManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("=== Watch WCSession 활성화 ===")
        print("활성화 상태: \(activationState.rawValue)")
        print("통신 가능: \(session.isReachable)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let text = message["message"] as? String {
                self.messageFromPhone = text
                print("iPhone으로부터 메시지 수신: \(text)")
            }
        }
    }
}
