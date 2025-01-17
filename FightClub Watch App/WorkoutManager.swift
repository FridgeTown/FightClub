import WatchConnectivity
import HealthKit

class WorkoutManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WorkoutManager()
    
    @Published var isReachable = false
    @Published var isWorkoutActive = false
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var workoutCalories: Double = 0  // 운동 세션 동안의 칼로리
    
    private var healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var heartRateQuery: HKQuery?
    private var updateTimer: Timer?
    private var lastMessageTime: Date?
    
    var wcSession: WCSession?
    
    private var backgroundTask: WKApplicationRefreshBackgroundTask?
    private var isBackgroundUpdateScheduled = false
    
    private override init() {
        super.init()
        setupWatchConnectivity()
        requestAuthorization()
        setupBackgroundUpdates()
        
        // 화면 꺼짐 방지 설정
        WKExtension.shared().isAutorotating = true
        WKExtension.shared().isFrontmostTimeoutExtended = true
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
        
        // 백그라운드 태스크 설정
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(),
            userInfo: ["type": "healthUpdate"],
            priority: .high
        ) { error in
            if let error = error {
                print("백그라운드 리프레시 설정 실패: \(error.localizedDescription)")
            }
        }
        
        // 활성화 즉시 응답 준비
        DispatchQueue.main.async { [weak self] in
            guard let session = self?.wcSession else { return }
            print("\n=== Watch 초기 상태 ===")
            print("활성화 상태: \(session.activationState.rawValue)")
            print("통신 가능: \(session.isReachable)")
            
            // iOS 앱으로 즉시 응답
            if session.activationState == .activated {
                self?.sendWatchStatus()
            }
        }
    }
    
    private func sendWatchStatus() {
        guard let session = wcSession, session.activationState == .activated else { return }
        
        let message: [String: Any] = [
            "status": "watchReady",
            "isActive": WKExtension.shared().applicationState != .background,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: { reply in
            print("iOS 앱 응답: \(reply)")
        }, errorHandler: { error in
            print("상태 전송 실패: \(error.localizedDescription)")
        })
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
                self.sendWatchStatus()
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
                    self.startWorkout()
                    replyHandler(["status": "started"])
                }
                
            case "stopWorkout":
                print("운동 종료 명령 수신")
                DispatchQueue.main.async {
                    self.stopWorkout()
                    replyHandler(["status": "stopped"])
                }
                
            case "activate":
                print("워치 앱 활성화 요청 수신")
                DispatchQueue.main.async {
                    self.activateWatchApp { success in
                        replyHandler(["success": success])
                    }
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
    
    // 재연결 시도 함수 수정
    private func retryConnection() {
        guard let session = wcSession else { return }
        
        // 앱 상태 확인 및 활성화
        let appState = WKExtension.shared().applicationState
        print("현재 워치 앱 상태: \(appState.rawValue)")
        
        if appState == .background {
            // 백그라운드에서 활성화 시도
            WKExtension.shared().activate { success in
                if success {
                    print("워치 앱 백그라운드 활성화 성공")
                    DispatchQueue.main.async {
                        session.activate()
                        self.sendWatchStatus()
                    }
                } else {
                    print("워치 앱 백그라운드 활성화 실패")
                    // 백그라운드 태스크 재설정
                    self.scheduleBackgroundRefresh()
                }
            }
        } else {
            // 이미 활성 상태면 세션만 활성화
            session.activate()
            self.sendWatchStatus()
        }
    }
    
    private func scheduleBackgroundRefresh() {
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date().addingTimeInterval(60), // 1분 후 재시도
            userInfo: nil
        ) { error in
            if let error = error {
                print("백그라운드 리프레시 재설정 실패: \(error.localizedDescription)")
            }
        }
    }
    
    // HealthKit 권한 요청
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
                    // 백그라운드 업데이트 활성화
                    for type in typesToRead {
                        self?.enableBackgroundDelivery(for: type as! HKQuantityType)
                    }
                    self?.startHeartRateMonitoring()
                    self?.startCaloriesMonitoring()
                }
            }
        }
    }
    
    // 백그라운드 업데이트 활성화를 위한 새로운 메서드
    private func enableBackgroundDelivery(for type: HKQuantityType) {
        healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { (success, error) in
            if let error = error {
                print("\(type.identifier) 백그라운드 업데이트 활성화 실패: \(error.localizedDescription)")
            }
            if success {
                print("\(type.identifier) 백그라운드 업데이트 활성화 성공")
            }
        }
    }
    
    // 심박수 모니터링 시작
    func startHeartRateMonitoring() {
        print("심박수 모니터링 시작")
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("심박수 타입을 가져올 수 없습니다")
            return
        }
        
        // 이전 쿼리와 타이머가 있다면 정지
        stopHeartRateMonitoring()
        
        // 심박수 쿼리 설정
        let heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processHeartRateSamples(samples as? [HKQuantitySample])
        }
        
        // 업데이트 핸들러 추가
        heartRateQuery.updateHandler = { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processHeartRateSamples(samples as? [HKQuantitySample])
        }
        
        heartRateQuery = heartRateQuery
        healthStore.execute(heartRateQuery)
    }
    
    // 칼로리 모니터링 시작
    func startCaloriesMonitoring() {
        print("칼로리 모니터링 시작")
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            print("칼로리 타입을 가져올 수 없습니다")
            return
        }
        
        // 이전 쿼리가 있다면 정지
        if let query = caloriesQuery {
            healthStore.stop(query)
        }
        
        // 칼로리 쿼리 설정
        let caloriesQuery = HKAnchoredObjectQuery(
            type: caloriesType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] (query, samples, deletedObjects, anchor, error) in
            if let error = error {
                print("칼로리 쿼리 에러: \(error.localizedDescription)")
                return
            }
            self?.processCaloriesSamples(samples as? [HKQuantitySample])
        }
        
        // 업데이트 핸들러 추가
        caloriesQuery.updateHandler = { [weak self] (query, samples, deletedObjects, anchor, error) in
            if let error = error {
                print("칼로리 업데이트 에러: \(error.localizedDescription)")
                return
            }
            self?.processCaloriesSamples(samples as? [HKQuantitySample])
        }
        
        self.caloriesQuery = caloriesQuery
        healthStore.execute(caloriesQuery)
    }
    
    // 칼로리 데이터 처리를 위한 새로운 메서드
    private func processCaloriesSamples(_ samples: [HKQuantitySample]?) {
        guard let samples = samples else { return }
        
        DispatchQueue.main.async {
            let calories = samples.reduce(0.0) { sum, sample in
                sum + sample.quantity.doubleValue(for: HKUnit.kilocalorie())
            }
            
            self.activeCalories = calories
            
            // 백그라운드 상태에서도 데이터 전송
            if let session = self.wcSession {
                do {
                    let context: [String: Any] = [
                        "type": "healthData",
                        "calories": calories,
                        "timestamp": Date().timeIntervalSince1970,
                        "isBackground": WKExtension.shared().applicationState == .background
                    ]
                    
                    try session.updateApplicationContext(context)
                    
                    session.sendMessage(context, replyHandler: nil) { error in
                        print("칼로리 메시지 전송 실패: \(error.localizedDescription)")
                    }
                    
                    print("칼로리 전송 성공 (백그라운드): \(calories) kcal")
                } catch {
                    print("칼로리 전송 실패 (백그라운드): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 심박수 모니터링 중지
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
    
    // 최신 심박수 가져오기
    private func fetchLatestHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-5), end: nil, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] (_, samples, error) in
            if let error = error {
                print("심박수 쿼리 에러: \(error.localizedDescription)")
                return
            }
            
            self?.processHeartRateSamples(samples)
        }
        
        healthStore.execute(query)
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else { return }
        
        DispatchQueue.main.async {
            guard let mostRecentSample = heartRateSamples.first else { return }
            
            let heartRate = mostRecentSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            self.heartRate = heartRate
            
            // 백그라운드 상태에서도 데이터 전송
            if let session = self.wcSession {
                do {
                    let context: [String: Any] = [
                        "type": "healthData",
                        "heartRate": heartRate,
                        "timestamp": Date().timeIntervalSince1970,
                        "isBackground": WKExtension.shared().applicationState == .background
                    ]
                    
                    try session.updateApplicationContext(context)
                    
                    session.sendMessage(context, replyHandler: nil) { error in
                        print("심박수 메시지 전송 실패: \(error.localizedDescription)")
                    }
                    
                    print("심박수 전송 성공 (백그라운드): \(heartRate) BPM")
                } catch {
                    print("심박수 전송 실패 (백그라운드): \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 최신 칼로리 데이터 가져오기
    private func fetchLatestCalories() {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: nil, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKStatisticsQuery(
            quantityType: caloriesType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] (_, statistics, error) in
            if let error = error {
                print("칼로리 쿼리 에러: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                let calories = statistics?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                self?.activeCalories = calories
                print("현재 소모 칼로리: \(calories) kcal")
                
                // Watch에서 iOS로 칼로리 데이터 전송
                if let session = self?.wcSession, session.isReachable {
                    do {
                        try session.updateApplicationContext([
                            "calories": calories,
                            "timestamp": Date().timeIntervalSince1970
                        ])
                        print("칼로리 전송 성공: \(calories) kcal")
                    } catch {
                        print("칼로리 전송 실패: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    // WCSessionDelegate에 필수 메서드 추가
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("앱 컨텍스트 수신: \(applicationContext)")
    }
    
    // 운동 세션 시작
    func startWorkout() {
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
            
            // 세션 시작
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { (success, error) in
                if let error = error {
                    print("운동 데이터 수집 시작 실패: \(error.localizedDescription)")
                    return
                }
                
                print("운동 세션 시작")
                DispatchQueue.main.async {
                    self.isWorkoutActive = true
                    self.workoutCalories = 0
                    
                    // 화면 꺼짐 방지 설정
                    WKExtension.shared().isFrontmostTimeoutExtended = true
                    
                    // 백그라운드 작업 시작
                    self.startBackgroundUpdates()
                }
            }
        } catch {
            print("운동 세션 생성 실패: \(error.localizedDescription)")
        }
    }
    
    private func startBackgroundUpdates() {
        // 심박수 모니터링 시작
        startHeartRateMonitoring()
        
        // 칼로리 모니터링 시작
        startCaloriesMonitoring()
        
        // 백그라운드 업데이트 스케줄링
        scheduleNextBackgroundUpdate()
    }
    
    // 운동 세션 종료
    func stopWorkout() {
        // 기존 정리 작업
        session?.end()
        stopHeartRateMonitoring()
        
        // 백그라운드 작업 정리
        isBackgroundUpdateScheduled = false
        WKExtension.shared().isFrontmostTimeoutExtended = false
        
        // 최종 데이터 전송
        builder?.endCollection(withEnd: Date()) { (success, error) in
            if let error = error {
                print("운동 데이터 수집 종료 실패: \(error.localizedDescription)")
                return
            }
            
            self.builder?.finishWorkout { (workout, error) in
                if let error = error {
                    print("운동 세션 종료 실패: \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.main.async {
                    self.isWorkoutActive = false
                    
                    // 최종 운동 데이터 전송
                    if let session = self.wcSession, session.isReachable {
                        do {
                            try session.updateApplicationContext([
                                "workoutEnded": true,
                                "finalCalories": self.workoutCalories,
                                "timestamp": Date().timeIntervalSince1970
                            ])
                            print("최종 운동 데이터 전송 성공")
                        } catch {
                            print("최종 운동 데이터 전송 실패: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    // 백그라운드 태스크 처리
    func handleBackgroundTask(_ task: WKApplicationRefreshBackgroundTask) {
        // 데이터 업데이트
        fetchLatestHeartRate()
        fetchLatestCalories()
        
        // 다음 업데이트 예약
        scheduleNextBackgroundUpdate()
        
        // 태스크 완료
        task.setTaskCompletedWithSnapshot(false)
    }
    
    // 백그라운드 태스크 갱신 주기 설정 (15분마다)
    private func scheduleNextBackgroundUpdate() {
        guard !isBackgroundUpdateScheduled else { return }
        
        let nextUpdate = Date().addingTimeInterval(15 * 60) // 15분
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: nextUpdate, userInfo: nil) { error in
            if let error = error {
                print("백그라운드 업데이트 스케줄링 실패: \(error.localizedDescription)")
            } else {
                self.isBackgroundUpdateScheduled = true
                print("다음 백그라운드 업데이트 예약됨: \(nextUpdate)")
            }
        }
    }
    
    // 워치 앱 활성화 함수 수정
    private func activateWatchApp(completion: @escaping (Bool) -> Void) {
        guard let session = wcSession else {
            completion(false)
            return
        }
        
        // 자동으로 워치 앱 활성화 시도
        WKExtension.shared().activate { success in
            if success {
                print("워치 앱 자동 활성화 성공")
                
                // 활성화 후 연결 상태 확인 및 세션 활성화
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if session.isReachable {
                        completion(true)
                    } else {
                        session.activate()
                        // 세션 활성화 후 추가 대기
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            completion(session.isReachable)
                        }
                    }
                }
            } else {
                print("워치 앱 자동 활성화 실패")
                completion(false)
            }
        }
    }
    
    // 백그라운드 데이터 업데이트 최적화
    private func setupBackgroundUpdates() {
        // 백그라운드 모드에서의 데이터 업데이트 빈도 설정
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        // 백그라운드 전송 활성화
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if success {
                print("심박수 백그라운드 업데이트 활성화 성공")
            } else if let error = error {
                print("심박수 백그라운드 업데이트 활성화 실패: \(error.localizedDescription)")
            }
        }
        
        healthStore.enableBackgroundDelivery(for: caloriesType, frequency: .immediate) { success, error in
            if success {
                print("칼로리 백그라운드 업데이트 활성화 성공")
            } else if let error = error {
                print("칼로리 백그라운드 업데이트 활성화 실패: \(error.localizedDescription)")
            }
        }
        
        // 백그라운드 태스크 설정
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(),
            userInfo: ["type": "healthUpdate"],
            priority: .high
        ) { error in
            if let error = error {
                print("백그라운드 리프레시 설정 실패: \(error.localizedDescription)")
            }
        }
        
        // 백그라운드 세션 설정
        let session = WKExtension.shared().delegate as? ExtensionDelegate
        session?.setupBackgroundSession()
        
        // 백그라운드 태스크 갱신 주기 설정 (15분마다)
        scheduleNextBackgroundUpdate()
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            self.isWorkoutActive = toState == .running
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("운동 세션 오류: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // 운동 이벤트 수집 시 처리
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { return }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            // 운동 중 칼로리 업데이트
            if quantityType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let calories = statistics?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                DispatchQueue.main.async {
                    self.workoutCalories = calories
                    print("운동 중 소모 칼로리: \(calories) kcal")
                    
                    // Watch에서 iOS로 실시간 칼로리 데이터 전송
                    if let session = self.wcSession, session.isReachable {
                        do {
                            try session.updateApplicationContext([
                                "workoutCalories": calories,
                                "timestamp": Date().timeIntervalSince1970
                            ])
                        } catch {
                            print("운동 중 칼로리 전송 실패: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - WKExtensionDelegate 처리
extension WorkoutManager {
    func applicationDidEnterBackground() {
        if isWorkoutActive {
            // 운동 중일 때만 백그라운드 업데이트 유지
            startBackgroundUpdates()
        }
    }
    
    func applicationWillEnterForeground() {
        if isWorkoutActive {
            // 즉시 데이터 업데이트
            fetchLatestHeartRate()
            fetchLatestCalories()
        }
    }
} 