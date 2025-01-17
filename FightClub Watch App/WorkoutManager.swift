import WatchConnectivity
import HealthKit

class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()
    
    @Published var isReachable = false
    @Published var isWorkoutActive = false
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var workoutCalories: Double = 0
    
    private var healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var heartRateQuery: HKQuery?
    private var updateTimer: Timer?
    private var lastMessageTime: Date?
    
    private var extendedSession: WKExtendedRuntimeSession?
    private var isExtendedSessionActive = false
    private var hasRequestedExtendedSession = false
    private var sessionRetryCount = 0
    private let maxRetryAttempts = 3
    
    private override init() {
        super.init()
        requestAuthorization()
        setupNotifications()
        setupConnectionMonitoring()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchMessage(_:)),
            name: .watchMessageReceived,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionStateChanged(_:)),
            name: .watchConnectionStateChanged,
            object: nil
        )
    }
    
    @objc private func handleConnectionStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let state = userInfo["state"] as? String else { return }
        
        DispatchQueue.main.async {
            if state == "connected" {
                print("Watch 연결 상태 변경: 연결됨")
                if self.isWorkoutActive {
                    self.startExtendedRuntimeSession()
                }
            } else {
                print("Watch 연결 상태 변경: 연결 끊김")
                self.cleanupExtendedSession()
            }
        }
    }
    
    @objc private func handleWatchMessage(_ notification: Notification) {
        guard let message = notification.userInfo as? [String: Any] else { return }
        
        if let command = message["command"] as? String {
            handleCommand(command, replyHandler: nil)
        }
    }
    
    private func handleCommand(_ command: String, replyHandler: (([String: Any]) -> Void)?) {
        switch command {
        case "startWorkout":
            DispatchQueue.main.async {
                self.startWorkout()
                replyHandler?(["status": "started"])
            }
            
        case "stopWorkout":
            DispatchQueue.main.async {
                self.stopWorkout()
                replyHandler?(["status": "stopped"])
            }
            
        case "status":
            let status = isWorkoutActive ? "active" : "inactive"
            replyHandler?(["workoutStatus": status])
            
        default:
            replyHandler?(["error": "unknown command"])
        }
    }
    
    private func requestAuthorization() {
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            if let error = error {
                print("HealthKit 권한 요청 실패: \(error.localizedDescription)")
                return
            }
            
            if success {
                print("HealthKit 권한 요청 성공")
                DispatchQueue.main.async {
                    self?.startHeartRateMonitoring()
                    self?.startCaloriesMonitoring()
                }
            }
        }
    }
    
    func startWorkout() {
        sessionRetryCount = 0
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .boxing
        configuration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                        workoutConfiguration: configuration)
            
            session?.delegate = self
            builder?.delegate = self
            
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { [weak self] (success, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("운동 데이터 수집 시작 실패: \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.main.async {
                    self.isWorkoutActive = true
                    self.workoutCalories = 0
                    
                    // 워크아웃 시작 후 약간의 지연을 두고 Extended Session 시작
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.startExtendedRuntimeSession()
                    }
                }
            }
        } catch {
            print("운동 세션 생성 실패: \(error.localizedDescription)")
        }
    }
    
    func stopWorkout() {
        cleanupExtendedSession()
        
        session?.end()
        stopHeartRateMonitoring()
        
        builder?.endCollection(withEnd: Date()) { [weak self] (success, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("운동 데이터 수집 종료 실패: \(error.localizedDescription)")
                return
            }
            
            self.builder?.finishWorkout { (workout, error) in
                DispatchQueue.main.async {
                    self.isWorkoutActive = false
                    self.sendWorkoutEndedContext()
                }
            }
        }
    }
    
    private func startExtendedRuntimeSession() {
        // 이미 활성화된 세션이 있는지 확인
        if let existingSession = extendedSession {
            switch existingSession.state {
            case .running:
                print("Extended session is already running")
                return
            case .invalid:
                print("Previous session was invalid, cleaning up")
                cleanupExtendedSession()
            default:
                break
            }
        }
        
        // 워크아웃이 활성 상태인지 확인
        guard isWorkoutActive else {
            print("Cannot start extended session: workout is not active")
            return
        }
        
        // 재시도 횟수 확인
        guard sessionRetryCount < maxRetryAttempts else {
            print("Max retry attempts reached for extended session")
            return
        }
        
        // 워크아웃 세션 상태 확인
        guard let session = session, session.state == .running else {
            print("Cannot start extended session: workout session is not running")
            return
        }
        
        print("Attempting to create extended runtime session (attempt \(sessionRetryCount + 1))")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 새 세션 생성
            let newSession = WKExtendedRuntimeSession()
            newSession.delegate = self
            self.extendedSession = newSession
            self.hasRequestedExtendedSession = true
            
            // 세션 시작 전 짧은 지연
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("Starting extended runtime session")
                newSession.start()
            }
        }
    }
    
    private func cleanupExtendedSession() {
        if let existingSession = extendedSession {
            print("Cleaning up extended session (state: \(existingSession.state.rawValue))")
            existingSession.invalidate()
            extendedSession = nil
        }
        isExtendedSessionActive = false
        hasRequestedExtendedSession = false
    }
    
    private func setupConnectionMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkConnectionStatus()
        }
    }
    
    private func checkConnectionStatus() {
        let isConnected = WatchConnectivityManager.shared.connectionState == .connected
        
        DispatchQueue.main.async {
            if self.isReachable != isConnected {
                self.isReachable = isConnected
                if !isConnected && self.isWorkoutActive {
                    self.handleConnectionLoss()
                }
            }
        }
    }
    
    private func handleConnectionLoss() {
        if isWorkoutActive {
            print("연결이 끊어짐, 재연결 시도 중...")
            attemptReconnection()
        }
    }
    
    private func attemptReconnection() {
        if let session = session, session.state == .running {
            startExtendedRuntimeSession()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.sendWorkoutStatus()
            }
        }
    }
    
    private func sendWorkoutStatus() {
        let context: [String: Any] = [
            "type": "workoutStatus",
            "isActive": isWorkoutActive,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WatchConnectivityManager.shared.sendApplicationContext(context)
    }
    
    private func sendWorkoutEndedContext() {
        let context: [String: Any] = [
            "workoutEnded": true,
            "finalCalories": workoutCalories,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WatchConnectivityManager.shared.sendApplicationContext(context)
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate
extension WorkoutManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        DispatchQueue.main.async {
            print("Extended runtime session started successfully")
            self.isExtendedSessionActive = true
            self.sessionRetryCount = 0
            self.sendWorkoutStatus()
        }
    }
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                              didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                              error: Error?) {
        DispatchQueue.main.async {
            print("Extended runtime session invalidated")
            print("Invalidation reason: \(reason.rawValue)")
            if let error = error {
                print("Error details: \(error.localizedDescription)")
            }
            
            self.cleanupExtendedSession()
            
            if self.isWorkoutActive && self.sessionRetryCount < self.maxRetryAttempts {
                self.sessionRetryCount += 1
                print("Scheduling retry attempt \(self.sessionRetryCount) of \(self.maxRetryAttempts)")
                
                let retryDelay = Double(self.sessionRetryCount) * 2.0
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                    self?.startExtendedRuntimeSession()
                }
            } else if self.sessionRetryCount >= self.maxRetryAttempts {
                print("Max retry attempts reached, giving up on extended session")
            }
        }
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        DispatchQueue.main.async {
            print("Extended runtime session will expire")
            self.sessionRetryCount = 0
            
            if self.isWorkoutActive {
                print("Starting new session before expiration")
                self.startExtendedRuntimeSession()
            }
        }
    }
} 