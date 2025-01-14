import HealthKit
import WatchConnectivity

class HealthKitManager: NSObject, ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private var session: WCSession?
    
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var isRecording = false
    
    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    private let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    
    override init() {
        super.init()
        setupWatchConnectivity()
        requestAuthorization()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("WCSession이 지원되지 않습니다")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        
        print("\n=== iOS App WCSession Setup ===")
        print("iOS 앱 번들 ID: \(Bundle.main.bundleIdentifier ?? "없음")")
        if let watchAppBundleID = Bundle.main.object(forInfoDictionaryKey: "WKAppBundleIdentifier") as? String {
            print("설정된 Watch 앱 번들 ID: \(watchAppBundleID)")
        }
        
        // 세션 활성화
        session?.activate()
        
        // 활성화 후 Watch App과의 연결 시도
        startWatchConnectionAttempt()
    }
    
    private func startWatchConnectionAttempt() {
        var attemptCount = 0
        let maxAttempts = 5
        
        func attemptConnection() {
            guard let session = session, attemptCount < maxAttempts else { return }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(attemptCount)) {
                print("\n=== Watch 연결 시도 (\(attemptCount + 1)/\(maxAttempts)) ===")
                print("활성화 상태: \(session.activationState.rawValue)")
                print("페어링 상태: \(session.isPaired)")
                print("워치 앱 설치됨: \(session.isWatchAppInstalled)")
                print("통신 가능: \(session.isReachable)")
                
                if session.isReachable {
                    print("Watch App과 연결 성공!")
                    // 연결 성공 시 테스트 메시지 전송
                    session.sendMessage(["test": "connection"], replyHandler: { reply in
                        print("Watch 응답: \(reply)")
                    }, errorHandler: { error in
                        print("통신 테스트 실패: \(error.localizedDescription)")
                    })
                } else {
                    attemptCount += 1
                    if attemptCount < maxAttempts {
                        print("재시도 중...")
                        attemptConnection()
                    } else {
                        print("최대 시도 횟수 초과")
                    }
                }
            }
        }
        
        attemptConnection()
    }
    
    func requestAuthorization() {
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
        let session = WCSession.default
        
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
    
     func startWorkoutSession() {
        let session = WCSession.default
        
        // 연결 상태 확인
        if !checkWatchConnection() {
            print("Watch 연결 상태 확인 필요:")
            print("- 페어링됨: \(session.isPaired)")
            print("- 앱 설치됨: \(session.isWatchAppInstalled)")
            print("- 통신 가능: \(session.isReachable)")
            return
        }
        
        // 메시지 전송
        session.sendMessage(["command": "startWorkout"], 
                           replyHandler: { reply in
            print("Watch 응답: \(reply)")
        }, errorHandler: { error in
            print("워치 통신 에러: \(error.localizedDescription)")
        })
    }
    
    func stopWorkoutSession() {
        isRecording = false
        
        // Watch 연결 상태 확인
        guard let session = session, 
              session.isPaired,
              session.isWatchAppInstalled else {
            return
        }
        
        // Watch에 운동 종료 알림
        session.sendMessage(["command": "stopWorkout"], replyHandler: nil) { error in
            print("워치 통신 에러: \(error.localizedDescription)")
        }
    }
    
    func checkHealthKitAuthorization() {
        let healthStore = HKHealthStore()
        
        if HKHealthStore.isHealthDataAvailable() {
            print("HealthKit 사용 가능")
            
            let typesToRead: Set<HKObjectType> = [
                HKObjectType.quantityType(forIdentifier: .heartRate)!,
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
            ]
            
            healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                if success {
                    print("HealthKit 권한 획득 성공")
                    self.startObservingHealthData()
                } else {
                    print("HealthKit 권한 획득 실패: \(error?.localizedDescription ?? "알 수 없는 오류")")
                }
            }
        } else {
            print("HealthKit을 사용할 수 없습니다")
        }
    }
    
    private func startObservingHealthData() {
        print("건강 데이터 모니터링 시작")
        // 여기에 실제 데이터 모니터링 코드 추가
    }
}

// WatchConnectivity 델리게이트 구현
extension HealthKitManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            print("\n=== iOS WCSession Activation ===")
            print("활성화 상태: \(activationState.rawValue)")
            print("페어링 상태: \(session.isPaired)")
            print("워치 앱 설치됨: \(session.isWatchAppInstalled)")
            print("통신 가능: \(session.isReachable)")
            
            if let error = error {
                print("활성화 오류: \(error.localizedDescription)")
            }
            
            // 활성화 성공 시 Watch App 검색
            if activationState == .activated {
                self?.startWatchAppDiscovery()
            }
        }
    }
    
    private func startWatchAppDiscovery() {
        guard let session = session else { return }
        
        // Watch App 검색 시도
        print("\n=== Watch App 검색 시작 ===")
        
        // 1초 간격으로 5번 시도
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i)) {
                if !session.isWatchAppInstalled {
                    print("검색 시도 \(i + 1): Watch App 찾는 중...")
                    
                    // 상태 확인
                    print("- 활성화 상태: \(session.activationState.rawValue)")
                    print("- 페어링 상태: \(session.isPaired)")
                    print("- 워치 앱 설치됨: \(session.isWatchAppInstalled)")
                    
//                     통신 테스트
                    session.sendMessage(["discover": "attempt_\(i)"], replyHandler: { reply in
                        print("Watch App 응답: \(reply)")
                    }, errorHandler: { error in
                        print("Watch App 검색 오류: \(error.localizedDescription)")
                    })
                } else {
                    print("Watch App 발견!")
                }
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession 비활성화됨")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession 비활성화 완료")
        WCSession.default.activate()
    }
    
    // Watch로부터 데이터 수신
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let heartRate = message["heartRate"] as? Double {
                self.heartRate = heartRate
            }
            if let calories = message["calories"] as? Double {
                self.activeCalories = calories
            }
        }
    }
    
    // WCSessionDelegate 메서드 수정
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("\n=== Watch 연결 상태 변경 ===")
            print("통신 가능: \(session.isReachable)")
            
            if session.isReachable {
                // Watch App이 연결 가능해지면 테스트 메시지 전송
                session.sendMessage(["status": "check"], replyHandler: { reply in
                    print("Watch 응답: \(reply)")
                }, errorHandler: { error in
                    print("상태 확인 실패: \(error.localizedDescription)")
                })
            } else {
                // 연결이 끊어지면 재연결 시도
                self.startWatchConnectionAttempt()
            }
        }
    }
} 
