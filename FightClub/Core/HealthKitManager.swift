import HealthKit
import WatchConnectivity

class HealthKitManager: NSObject, ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private var session: WCSession?
    
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var isRecording = false
    @Published var watchConnectionStatus: String = "초기화 중..."
    
    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    private let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    
    override init() {
        super.init()
        setupWatchConnectivity()
        requestAuthorization()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            self.session = session
            
            print("\n=== iOS App WCSession Setup ===")
            print("iOS 앱 번들 ID: \(Bundle.main.bundleIdentifier ?? "없음")")
            if let watchAppBundleID = Bundle.main.object(forInfoDictionaryKey: "WKAppBundleIdentifier") as? String {
                print("설정된 Watch 앱 번들 ID: \(watchAppBundleID)")
            }
        }
    }
    
    private func requestAuthorization() {
        let typesToRead: Set<HKObjectType> = [heartRateType, activeEnergyType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                print("HealthKit 권한 획득 성공")
            } else if let error = error {
                print("HealthKit 권한 획득 실패: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkWatchConnection() -> Bool {
        guard let session = self.session else { return false }
        
        guard session.isPaired else {
            print("Apple Watch가 페어링되지 않았습니다")
            return false
        }
        
        guard session.isWatchAppInstalled else {
            print("Watch App이 설치되지 않았습니다")
            return false
        }
        
        guard session.isReachable else {
            print("Watch App과 통신할 수 없습니다")
            return false
        }
        
        return true
    }
    
    // MARK: - Workout Session Management
    func startWorkoutSession() {
        guard let session = self.session else { return }
        
        if !checkWatchConnection() {
            print("Watch 연결 상태 확인 필요:")
            print("- 페어링됨: \(session.isPaired)")
            print("- 앱 설치됨: \(session.isWatchAppInstalled)")
            print("- 통신 가능: \(session.isReachable)")
            return
        }
        
        // 실시간 메시지 전송
        if session.isReachable {
            sendWorkoutCommand("startWorkout")
        } else {
            // Background 전송
            sendBackgroundWorkoutCommand("startWorkout")
        }
    }
    
    func stopWorkoutSession() {
        guard let session = self.session else { return }
        
        if !checkWatchConnection() {
            return
        }
        
        // 실시간 메시지 전송
        if session.isReachable {
            sendWorkoutCommand("stopWorkout")
        } else {
            // Background 전송
            sendBackgroundWorkoutCommand("stopWorkout")
        }
    }
    
    // MARK: - Message Sending Methods
    private func sendWorkoutCommand(_ command: String) {
        guard let session = self.session else { return }
        
        // 메시지 형식을 Watch App 기대형식에 맞춤
        let message: [String: Any] = [
            "command": command,
            "timestamp": Date().timeIntervalSince1970,
            "type": "workout"  // 명령의 타입을 명시
        ]
        
        print("전송할 메시지: \(message)")  // 디버깅용 로그
        
        session.sendMessage(message, replyHandler: { reply in
            print("Watch 응답 received: \(reply)")
            
            // 응답 처리
            if let error = reply["error"] as? String {
                print("Watch 에러 응답: \(error)")
            } else if let status = reply["status"] as? String {
                print("Watch 상태 응답: \(status)")
                
                // 상태에 따른 처리
                switch status {
                    case "started":
                        self.isRecording = true
                    case "stopped":
                        self.isRecording = false
                    default:
                        print("알 수 없는 상태: \(status)")
                }
            }
            
        }, errorHandler: { error in
            print("메시지 전송 실패: \(error.localizedDescription)")
            // 실패 시 Background 전송
            self.sendBackgroundWorkoutCommand(command)
        })
    }

    
    // Background 전송용 메서드도 동일한 형식으로 수정
    private func sendBackgroundWorkoutCommand(_ command: String) {
        guard let session = self.session else { return }
        
        let userInfo: [String: Any] = [
            "command": command,
            "timestamp": Date().timeIntervalSince1970,
            "type": "workout"
        ]
        
        print("Background 전송할 메시지: \(userInfo)")  // 디버깅용 로그
        
        do {
            try session.updateApplicationContext(userInfo)
            print("Background 명령 전송 성공: \(command)")
            
            // 상태 업데이트
            if command == "stopWorkout" {
                self.isRecording = false
            } else if command == "startWorkout" {
                self.isRecording = true
            }
        } catch {
            print("Background 명령 전송 실패: \(error.localizedDescription)")
        }
    }
    
    // 현재 상태 확인용 메서드 추가
    func checkWorkoutStatus() {
        guard let session = self.session, session.isReachable else {
            print("Watch 연결 안됨")
            return
        }
        
        let statusMessage: [String: Any] = [
            "command": "status",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        print("상태 확인 메시지 전송: \(statusMessage)")
        
        session.sendMessage(statusMessage, replyHandler: { reply in
            print("상태 확인 응답: \(reply)")
            
            if let status = reply["workoutStatus"] as? String {
                print("현재 운동 상태: \(status)")
                self.isRecording = (status == "active")
            }
        }, errorHandler: { error in
            print("상태 확인 실패: \(error.localizedDescription)")
        })
    }
}

// MARK: - WCSessionDelegate
@objc extension HealthKitManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.watchConnectionStatus = "활성화 실패: \(error.localizedDescription)"
                return
            }
            
            switch activationState {
            case .activated:
                self.watchConnectionStatus = "세션 활성화됨"
            case .inactive:
                self.watchConnectionStatus = "세션 비활성화됨"
            case .notActivated:
                self.watchConnectionStatus = "세션 활성화되지 않음"
            @unknown default:
                self.watchConnectionStatus = "알 수 없는 상태"
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.watchConnectionStatus = "세션 비활성화됨"
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.watchConnectionStatus = "세션 비활성화 완료"
            // iOS에서는 새로운 세션을 활성화
            WCSession.default.activate()
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let heartRate = message["heartRate"] as? Double {
                self.heartRate = heartRate
            }
            if let calories = message["calories"] as? Double {
                self.activeCalories = calories
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            if let command = applicationContext["command"] as? String {
                print("Background 명령 수신: \(command)")
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.watchConnectionStatus = session.isReachable ? "Watch 연결됨" : "Watch 연결 끊김"
            
            if session.isReachable {
                session.sendMessage(["status": "check"], replyHandler: { reply in
                    print("sessionReachabilityDidChange, Watch 응답: \(reply)")
                }, errorHandler: { error in
                    print("상태 확인 실패: \(error.localizedDescription)")
                })
            }
        }
    }
}
