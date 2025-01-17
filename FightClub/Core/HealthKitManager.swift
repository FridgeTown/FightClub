import HealthKit
import WatchConnectivity

class HealthKitManager: NSObject, ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private var session: WCSession?
    private var heartRateQuery: HKQuery?
    private var caloriesQuery: HKQuery?
    private var updateTimer: Timer?
    
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var isRecording = false
    @Published var watchConnectionStatus: String = "초기화 중..."
    @Published var workoutCalories: Double = 0
    
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
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [heartRateType, activeEnergyType]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            if success {
                print("HealthKit 권한 획득 성공")
                DispatchQueue.main.async {
                    self?.startHeartRateMonitoring()
                    self?.startCaloriesMonitoring()
                }
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
        
        startBackgroundUpdates()
    }
    
    func stopWorkoutSession() {
        stopHeartRateMonitoring()
        
        guard let session = self.session else { return }
        
        // 실시간 메시지 전송
        if session.isReachable {
            sendWorkoutCommand("stopWorkout")
        } else {
            // Background 전송
            sendBackgroundWorkoutCommand("stopWorkout")
        }
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    private func startBackgroundUpdates() {
        startHeartRateMonitoring()
        startCaloriesMonitoring()
    }
    
    private func startHeartRateMonitoring() {
        print("심박수 모니터링 시작")
        
        // 이전 쿼리가 있다면 정지
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        
        // 심박수 쿼리 설정
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processHeartRateSamples(samples as? [HKQuantitySample])
        }
        
        // 업데이트 핸들러 추가
        query.updateHandler = { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processHeartRateSamples(samples as? [HKQuantitySample])
        }
        
        heartRateQuery = query
        healthStore.execute(query)
    }
    
    private func startCaloriesMonitoring() {
        print("칼로리 모니터링 시작")
        
        // 이전 쿼리가 있다면 정지
        if let query = caloriesQuery {
            healthStore.stop(query)
            caloriesQuery = nil
        }
        
        // 칼로리 쿼리 설정
        let query = HKAnchoredObjectQuery(
            type: activeEnergyType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processCaloriesSamples(samples as? [HKQuantitySample])
        }
        
        // 업데이트 핸들러 추가
        query.updateHandler = { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processCaloriesSamples(samples as? [HKQuantitySample])
        }
        
        caloriesQuery = query
        healthStore.execute(query)
    }
    
    private func processHeartRateSamples(_ samples: [HKQuantitySample]?) {
        guard let samples = samples else { return }
        
        DispatchQueue.main.async {
            guard let mostRecentSample = samples.first else { return }
            
            let heartRate = mostRecentSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            self.heartRate = heartRate
            
            // 데이터 전송
            if let session = self.session, session.isReachable {
                do {
                    let context: [String: Any] = [
                        "type": "healthData",
                        "heartRate": heartRate,
                        "timestamp": Date().timeIntervalSince1970
                    ]
                    
                    try session.updateApplicationContext(context)
                    print("심박수 전송 성공: \(heartRate) BPM")
                } catch {
                    print("심박수 전송 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func processCaloriesSamples(_ samples: [HKQuantitySample]?) {
        guard let samples = samples else { return }
        
        DispatchQueue.main.async {
            let calories = samples.reduce(0.0) { sum, sample in
                sum + sample.quantity.doubleValue(for: HKUnit.kilocalorie())
            }
            
            self.activeCalories = calories
            
            // 데이터 전송
            if let session = self.session, session.isReachable {
                do {
                    let context: [String: Any] = [
                        "type": "healthData",
                        "calories": calories,
                        "timestamp": Date().timeIntervalSince1970
                    ]
                    
                    try session.updateApplicationContext(context)
                    print("칼로리 전송 성공: \(calories) kcal")
                } catch {
                    print("칼로리 전송 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func stopHeartRateMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        
        if let query = caloriesQuery {
            healthStore.stop(query)
            caloriesQuery = nil
        }
        
        updateTimer?.invalidate()
        updateTimer = nil
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
                DispatchQueue.main.async {
                    switch status {
                        case "started":
                            self.isRecording = true
                        case "stopped":
                            self.isRecording = false
                        default:
                            print("알 수 없는 상태: \(status)")
                    }
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
                print("심장박동수 받음", heartRate)
            }
            if let calories = message["calories"] as? Double {
                self.activeCalories = calories
                print("칼로리 받음", calories)
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            
            print("applicationContext", applicationContext)
            if let command = applicationContext["command"] as? String {
                print("Background 명령 수신: \(command)")
            }
            
            if let heartRate = applicationContext["heartRate"] as? Double {
                print("심박수 iOS수신")
                self.heartRate = heartRate
            }
            
            if let calories = applicationContext["calories"] as? Int {
                print("칼로리 수신 ")
                self.activeCalories = Double(calories)
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
