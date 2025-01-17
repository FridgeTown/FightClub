import WatchConnectivity
import HealthKit
import WatchKit
import CoreMotion

class WorkoutManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate, WKExtendedRuntimeSessionDelegate, WCSessionDelegate {
    static let shared = WorkoutManager()
    
    @Published var isReachable = false
    @Published var isWorkoutActive = false
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var workoutCalories: Double = 0
    @Published var currentPunchSpeed: Double = 0.0
    
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
    
    private var motionManager: CMMotionManager?
    private var punchSpeedBuffer: [Double] = []
    private let punchThreshold: Double = 3.0 // 펀치로 인식할 최소 가속도 (g)
    private var lastPunchTime: Date?
    private let minTimeBetweenPunches = 0.3 // 연속 펀치 인식 최소 시간 간격 (초)
    
    // MARK: - Notification Names
    private enum NotificationName {
        static let watchMessageReceived = Notification.Name("watchMessageReceived")
        static let watchConnectionStateChanged = Notification.Name("watchConnectionStateChanged")
        static let watchContextReceived = Notification.Name("watchContextReceived")
    }
    
    private override init() {
        super.init()
        setupMotionManager()
        setupWatchConnectivity()
        requestAuthorization()
        setupNotifications()
        setupConnectionMonitoring()
    }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("Watch Connectivity 설정 완료")
        } else {
            print("Watch Connectivity가 지원되지 않습니다")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWatchMessage(_:)),
            name: NotificationName.watchMessageReceived,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionStateChanged(_:)),
            name: NotificationName.watchConnectionStateChanged,
            object: nil
        )
    }
    
    private func setupMotionManager() {
        motionManager = CMMotionManager()
        guard let motionManager = motionManager else {
            print("모션 매니저 초기화 실패")
            return
        }
        
        // 가속도계만 필수로 체크
        if !motionManager.isAccelerometerAvailable {
            print("가속도계를 사용할 수 없습니다")
            return
        }
        
        motionManager.accelerometerUpdateInterval = 1.0 / 30.0 // 30Hz로 조정
        
        // 자이로스코프는 선택적으로 사용
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 1.0 / 30.0
            print("자이로스코프 사용 가능")
        }
        
        print("모션 매니저 설정 완료")
    }
    
    private func startMotionUpdates() {
        guard let motionManager = motionManager else {
            print("모션 매니저가 초기화되지 않았습니다")
            return
        }
        
        // 가속도계 시작
        if motionManager.isAccelerometerAvailable {
            motionManager.startAccelerometerUpdates(to: OperationQueue.main) { [weak self] (data, error) in
                guard let self = self,
                      let data = data else {
                    if let error = error {
                        print("가속도계 업데이트 에러: \(error.localizedDescription)")
                    }
                    return
                }
                
                self.processPunchData(accelerometerData: data)
            }
            print("가속도계 업데이트 시작")
        }
        
        // 자이로스코프는 선택적으로 시작
        if motionManager.isGyroAvailable {
            motionManager.startGyroUpdates(to: OperationQueue.main) { [weak self] (data, error) in
                if let error = error {
                    print("자이로스코프 업데이트 에러: \(error.localizedDescription)")
                }
            }
            print("자이로스코프 업데이트 시작")
        }
    }
    
    private func stopMotionUpdates() {
        motionManager?.stopAccelerometerUpdates()
        motionManager?.stopGyroUpdates()
        punchSpeedBuffer.removeAll()
    }
    
    private func processPunchData(accelerometerData: CMAccelerometerData) {
        // 3축 가속도의 크기 계산
        let acceleration = sqrt(
            pow(accelerometerData.acceleration.x, 2) +
            pow(accelerometerData.acceleration.y, 2) +
            pow(accelerometerData.acceleration.z, 2)
        )
        
        // 중력 가속도(1g) 제거
        let netAcceleration = abs(acceleration - 1.0)
        
        // 펀치 감지 로직
        if netAcceleration > punchThreshold {
            let now = Date()
            // 연속 펀치 필터링
            if lastPunchTime == nil || now.timeIntervalSince(lastPunchTime!) > minTimeBetweenPunches {
                lastPunchTime = now
                
                // 속도 계산 (가속도 * 시간)
                let punchSpeed = netAcceleration * 9.81 // m/s로 변환
                punchSpeedBuffer.append(punchSpeed)
                
                // 현재 펀치 속도 업데이트
                currentPunchSpeed = punchSpeed
                
                // 실시간 데이터 전송
                if WCSession.default.isReachable {
                    let message: [String: Any] = [
                        "type": "punchData",
                        "speed": punchSpeed,
                        "timestamp": now.timeIntervalSince1970
                    ]
                    
                    WCSession.default.sendMessage(message, replyHandler: nil) { error in
                        print("펀치 데이터 전송 실패: \(error.localizedDescription)")
                    }
                }
                
                // 최대 속도와 평균 속도 계산 및 전송 (누적 데이터)
                if let maxSpeed = punchSpeedBuffer.max() {
                    let avgSpeed = punchSpeedBuffer.reduce(0.0, +) / Double(punchSpeedBuffer.count)
                    let context: [String: Any] = [
                        "type": "punchStats",
                        "maxSpeed": maxSpeed,
                        "avgSpeed": avgSpeed,
                        "timestamp": now.timeIntervalSince1970
                    ]
                    sendContext(context)
                }
                
                // 버퍼 크기 제한
                if punchSpeedBuffer.count > 50 {
                    punchSpeedBuffer.removeFirst()
                }
            }
        }
    }
    
    // MARK: - Heart Rate Monitoring
    private func startHeartRateMonitoring() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        // 현재 시간부터 데이터 수집
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        // 쿼리 설정
        let query = HKObserverQuery(sampleType: heartRateType, predicate: predicate) { [weak self] (query, completionHandler, error) in
            if let error = error {
                print("심박수 관찰 에러: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            // 최신 심박수 데이터 가져오기
            let heartRateQuery = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] (query, samples, error) in
                guard let samples = samples as? [HKQuantitySample],
                      let mostRecentSample = samples.first else {
                    completionHandler()
                    return
                }
                
                self?.processHeartRateSamples([mostRecentSample])
                completionHandler()
            }
            
            self?.healthStore.execute(heartRateQuery)
        }
        
        // 백그라운드 업데이트 활성화
        healthStore.enableBackgroundDelivery(for: heartRateType,
                                           frequency: .immediate) { (success, error) in
            if let error = error {
                print("백그라운드 업데이트 활성화 실패: \(error.localizedDescription)")
            }
            if success {
                print("백그라운드 심박수 업데이트 활성화됨")
            }
        }
        
        // 쿼리 실행
        healthStore.execute(query)
        print("심박수 모니터링 시작")
    }
    
    private func processHeartRateSamples(_ samples: [HKQuantitySample]) {
        guard let mostRecentSample = samples.first else { return }
        
        // 현재 시간
        let now = Date()
        
        // 마지막 전송 시간 체크 (3초 간격)
        if let lastMessageTime = lastMessageTime, 
           now.timeIntervalSince(lastMessageTime) < 3.0 {
            return
        }
        
        DispatchQueue.main.async {
            let heartRate = mostRecentSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            self.heartRate = heartRate
            self.lastMessageTime = now
            
            // 심박수 데이터 전송
            self.sendHealthData()
            print("심박수 업데이트: \(heartRate) BPM")
        }
    }
    
    private func sendHealthData() {
        let context: [String: Any] = [
            "type": "healthData",
            "heartRate": heartRate,
            "calories": activeCalories,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 데이터 전송
        if WCSession.default.isReachable {
            // 실시간성이 필요한 경우 메시지로 전송
            WCSession.default.sendMessage(context, replyHandler: nil) { error in
                print("심박수 데이터 전송 실패: \(error.localizedDescription)")
            }
        } else {
            // 연결이 없는 경우 컨텍스트 업데이트
            sendContext(context)
        }
    }
    
    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.isWorkoutActive = toState == .running
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { return }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            DispatchQueue.main.async {
                switch quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                    self.heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                    
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    let energyUnit = HKUnit.kilocalorie()
                    self.activeCalories = statistics?.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
                    
                default:
                    return
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }
    
    // MARK: - Context Sending
    private func sendContext(_ context: [String: Any]) {
        guard WCSession.isSupported() else {
            print("WCSession이 지원되지 않습니다")
            return
        }
        
        let session = WCSession.default
        guard session.activationState == .activated else {
            print("WCSession이 활성화되지 않았습니다")
            return
        }
        
        // 컨텍스트에 타임스탬프가 없으면 추가
        var updatedContext = context
        if updatedContext["timestamp"] == nil {
            updatedContext["timestamp"] = Date().timeIntervalSince1970
        }
        
        do {
            try session.updateApplicationContext(updatedContext)
            print("컨텍스트 전송 성공: \(updatedContext)")
        } catch {
            print("컨텍스트 전송 실패: \(error.localizedDescription)")
            
            // 실패 시 메시지로 재시도
            if session.isReachable {
                session.sendMessage(updatedContext, replyHandler: nil) { error in
                    print("메시지 전송도 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func checkConnectionStatus() {
        guard WCSession.isSupported() else { return }
        
        let session = WCSession.default
        let isConnected = session.isReachable && session.activationState == .activated
        
        DispatchQueue.main.async {
            if self.isReachable != isConnected {
                self.isReachable = isConnected
                if !isConnected && self.isWorkoutActive {
                    self.handleConnectionLoss()
                }
            }
        }
    }
    
    private func sendWorkoutStatus() {
        let context: [String: Any] = [
            "type": "workoutStatus",
            "isActive": isWorkoutActive,
            "heartRate": heartRate,
            "calories": activeCalories,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendContext(context)
    }
    
    private func sendWorkoutEndedContext() {
        let context: [String: Any] = [
            "workoutEnded": true,
            "finalCalories": workoutCalories,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendContext(context)
    }
    
    // MARK: - Authorization
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
                }
            }
        }
    }
    
    // MARK: - Connection Monitoring
    private func setupConnectionMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkConnectionStatus()
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
    
    // MARK: - Message Handling
    @objc private func handleWatchMessage(_ notification: Notification) {
        guard let message = notification.userInfo as? [String: Any] else {
            print("잘못된 메시지 형식")
            return
        }
        
        print("워치 메시지 수신: \(message)")
        
        if let type = message["type"] as? String {
            switch type {
            case "workout":
                if let command = message["command"] as? String {
                    handleWorkoutCommand(command)
                }
            case "punchData":
                if let speed = message["speed"] as? Double {
                    handlePunchData(speed)
                }
            default:
                print("알 수 없는 메시지 타입: \(type)")
            }
        }
    }
    
    private func handleWorkoutCommand(_ command: String) {
        switch command {
        case "startWorkout":
            print("운동 시작 명령 수신")
            startWorkout()
        case "stopWorkout":
            print("운동 종료 명령 수신")
            stopWorkout()
        default:
            print("알 수 없는 운동 명령: \(command)")
        }
    }
    
    private func handlePunchData(_ speed: Double) {
        currentPunchSpeed = speed
        punchSpeedBuffer.append(speed)
        
        // 최대/평균 속도 계산 및 전송
        if let maxSpeed = punchSpeedBuffer.max() {
            let avgSpeed = punchSpeedBuffer.reduce(0.0, +) / Double(punchSpeedBuffer.count)
            let context: [String: Any] = [
                "type": "punchStats",
                "maxSpeed": maxSpeed,
                "avgSpeed": avgSpeed,
                "timestamp": Date().timeIntervalSince1970
            ]
            sendContext(context)
        }
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
    
    // MARK: - Workout Management
    func startWorkout() {
        sessionRetryCount = 0
        punchSpeedBuffer.removeAll()
        
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
        
        // 모션 업데이트 시작 추가
        startMotionUpdates()
    }
    
    func stopWorkout() {
        // 모션 업데이트 중지 추가
        stopMotionUpdates()
        
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
    
    // MARK: - Extended Runtime Session
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

// MARK: - WKExtendedRuntimeSessionDelegate
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
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("WCSession 활성화 실패: \(error.localizedDescription)")
                return
            }
            
            switch activationState {
            case .activated:
                print("WCSession 활성화 성공")
                self.isReachable = session.isReachable
                // 활성화 직후 현재 상태 전송
                if self.isWorkoutActive {
                    self.sendWorkoutStatus()
                }
            case .inactive:
                print("WCSession 비활성화 상태")
                self.isReachable = false
            case .notActivated:
                print("WCSession 활성화되지 않음")
                self.isReachable = false
            @unknown default:
                print("WCSession 알 수 없는 상태")
                self.isReachable = false
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            print("앱 컨텍스트 수신: \(applicationContext)")
            NotificationCenter.default.post(
                name: NotificationName.watchContextReceived,
                object: nil,
                userInfo: applicationContext
            )
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NotificationName.watchMessageReceived,
                object: nil,
                userInfo: message
            )
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NotificationName.watchMessageReceived,
                object: nil,
                userInfo: message
            )
            replyHandler(["status": "received"])
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if !session.isReachable && self.isWorkoutActive {
                self.handleConnectionLoss()
            }
        }
    }
    
    private func stopHeartRateMonitoring() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        // 백그라운드 업데이트 비활성화
        healthStore.disableBackgroundDelivery(for: heartRateType) { (success, error) in
            if let error = error {
                print("백그라운드 업데이트 비활성화 실패: \(error.localizedDescription)")
            }
            if success {
                print("백그라운드 심박수 업데이트 비활성화됨")
            }
        }
        
        // 기존 쿼리 중지
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
            print("심박수 모니터링 중지")
        }
    }
}

