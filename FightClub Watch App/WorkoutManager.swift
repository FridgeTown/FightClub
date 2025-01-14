import WatchConnectivity
import HealthKit

class WorkoutManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isReachable = false
    
    var wcSession: WCSession?
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("WCSession이 지원되지 않습니다")
            return
        }
        
        print("\n=== Watch App 번들 ID 확인 ===")
        print("현재 번들 ID: \(Bundle.main.bundleIdentifier ?? "없음")")
        print("Companion 앱 ID: \(Bundle.main.object(forInfoDictionaryKey: "WKCompanionAppBundleIdentifier") as? String ?? "없음")")
        
        wcSession = WCSession.default
        wcSession?.delegate = self
        wcSession?.activate()
        
        // 활성화 즉시 응답 준비
        DispatchQueue.main.async { [weak self] in
            guard let session = self?.wcSession else { return }
            print("\n=== Watch 초기 상태 ===")
            print("활성화 상태: \(session.activationState.rawValue)")
            print("통신 가능: \(session.isReachable)")
            
            // iOS 앱으로 즉시 응답
            if session.activationState == .activated {
                session.sendMessage(["status": "watchReady"], 
                                 replyHandler: { reply in
                    print("iOS 앱 응답: \(reply)")
                }, errorHandler: { error in
                    print("초기 통신 실패: \(error.localizedDescription)")
                })
            }
        }
    }
    
    // WCSessionDelegate 메서드
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            print("\n=== Watch Session Activation ===")
            print("활성화 상태: \(activationState.rawValue)")
            print("통신 가능 여부: \(session.isReachable)")
            
            self.isReachable = session.isReachable
            
            if let error = error {
                print("활성화 오류: \(error.localizedDescription)")
            }
            
            // 활성화 성공 시 iOS 앱에 응답 준비
            if activationState == .activated {
                print("iOS 앱 응답 준비 완료")
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("\n=== Watch 연결 상태 변경 ===")
            print("통신 가능: \(session.isReachable)")
            
            if session.isReachable {
                // 연결되면 iOS 앱에 상태 알림
                session.sendMessage(["status": "connected"], 
                                 replyHandler: { reply in
                    print("iOS 앱 응답: \(reply)")
                }, errorHandler: { error in
                    print("iOS 앱 통신 오류: \(error.localizedDescription)")
                })
            } else {
                // 연결이 끊어지면 재연결 시도
                self.retryConnection()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("메시지 수신: \(message)")
        
        // 운동 시작 명령 처리
        if let command = message["command"] as? String {
            switch command {
            case "startWorkout":
                print("운동 시작 명령 수신")
                DispatchQueue.main.async {
                    // 운동 시작 로직
                    replyHandler(["status": "started"])
                }
                
            case "stopWorkout":
                print("운동 종료 명령 수신")
                DispatchQueue.main.async {
                    // 운동 종료 로직
                    replyHandler(["status": "stopped"])
                }
                
            default:
                print("알 수 없는 명령: \(command)")
                replyHandler(["error": "unknown command"])
            }
        } else if message["test"] != nil {
            print("테스트 메시지 수신")
            replyHandler(["response": "fromWatch"])
        }
    }
    
    // 필수 WCSessionDelegate 메서드
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("메시지 수신 (no reply): \(message)")
    }
    
    // 재연결 시도 함수
    private func retryConnection() {
        guard let session = wcSession else { return }
        
        var retryCount = 0
        let maxRetries = 3
        
        func attemptReconnect() {
            guard retryCount < maxRetries else {
                print("최대 재시도 횟수 초과")
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount + 1)) {
                print("재연결 시도 \(retryCount + 1)/\(maxRetries)")
                
                if !session.isReachable {
                    session.activate()
                    retryCount += 1
                    attemptReconnect()
                } else {
                    print("재연결 성공")
                }
            }
        }
        
        attemptReconnect()
    }
} 