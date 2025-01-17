import Foundation
import WatchConnectivity
import WatchKit
import HealthKit

class WorkoutManager: NSObject, ObservableObject, WCSessionDelegate {
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
    private var caloriesQuery: HKQuery?  // 추가된 프로퍼티
    private var updateTimer: Timer?
    private var lastMessageTime: Date?
    private var extendedSession: WKExtendedRuntimeSession?
    
    var wcSession: WCSession?
    
    private override init() {
        super.init()
        setupWatchConnectivity()
        requestAuthorization()
        setupBackgroundUpdates()
        startExtendedRuntimeSession()
    }
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            print("WCSession이 지원되지 않습니다")
            return
        }
        
        wcSession = WCSession.default
        wcSession?.delegate = self
        wcSession?.activate()
        
        // 백그라운드 태스크 설정
        let date = Date(timeIntervalSinceNow: 60)
        let userInfo = NSDictionary(dictionary: ["timestamp": NSNumber(value: Date().timeIntervalSince1970)])
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: date,
            userInfo: userInfo
        ) { error in
            if let error = error {
                print("백그라운드 리프레시 설정 실패: \(error.localizedDescription)")
            }
        }
        
        // 활성화 즉시 응답 준비
        DispatchQueue.main.async { [weak self] in
            guard let session = self?.wcSession else { return }
            if session.activationState == .activated {
                self?.sendWatchStatus()
            }
        }
    }
    
    private func setupBackgroundUpdates() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        
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
        
        // 다음 백그라운드 업데이트 예약
        scheduleNextBackgroundUpdate()
    }
    
    private func scheduleNextBackgroundUpdate() {
        let date = Date(timeIntervalSinceNow: 15 * 60) // 15분 후
        let userInfo = NSDictionary(dictionary: ["timestamp": NSNumber(value: Date().timeIntervalSince1970)])
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: date,
            userInfo: userInfo
        ) { error in
            if let error = error {
                print("백그라운드 업데이트 스케줄링 실패: \(error.localizedDescription)")
            } else {
                print("다음 백그라운드 업데이트 예약됨: \(date)")
            }
        }
    }
    
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
            
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { (success, error) in
                if let error = error {
                    print("운동 데이터 수집 시작 실패: \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.main.async {
                    self.isWorkoutActive = true
                    self.workoutCalories = 0
                    self.startBackgroundUpdates()
                }
            }
        } catch {
            print("운동 세션 생성 실패: \(error.localizedDescription)")
        }
    }
    
    private func startBackgroundUpdates() {
        startHeartRateMonitoring()
        startCaloriesMonitoring()
        scheduleNextBackgroundUpdate()
    }
    
    func stopWorkout() {
        session?.end()
        stopHeartRateMonitoring()
        
        builder?.endCollection(withEnd: Date()) { (success, error) in
            if let error = error {
                print("운동 데이터 수집 종료 실패: \(error.localizedDescription)")
                return
            }
            
            self.builder?.finishWorkout { (workout, error) in
                DispatchQueue.main.async {
                    self.isWorkoutActive = false
                    if let session = self.wcSession, session.isReachable {
                        do {
                            try session.updateApplicationContext([
                                "workoutEnded": true,
                                "finalCalories": self.workoutCalories,
                                "timestamp": Date().timeIntervalSince1970
                            ])
                        } catch {
                            print("최종 운동 데이터 전송 실패: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    // WCSessionDelegate 필수 메서드들
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("메시지 수신: \(message)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("메시지 수신 (응답 필요): \(message)")
        replyHandler(["status": "received"])
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
    
    func startHeartRateMonitoring() {
        print("심박수 모니터링 시작")
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("심박수 타입을 가져올 수 없습니다")
            return
        }
        
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
    
    func startCaloriesMonitoring() {
        print("칼로리 모니터링 시작")
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            print("칼로리 타입을 가져올 수 없습니다")
            return
        }
        
        // 이전 쿼리가 있다면 정지
        if let query = caloriesQuery {
            healthStore.stop(query)
            caloriesQuery = nil
        }
        
        // 칼로리 쿼리 설정
        let query = HKAnchoredObjectQuery(
            type: caloriesType,
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
            if let session = self.wcSession, session.isReachable {
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
            if let session = self.wcSession, session.isReachable {
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
    
    private func startExtendedRuntimeSession() {
        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.delegate = self
        extendedSession?.start()
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
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { return }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            if quantityType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let calories = statistics?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                DispatchQueue.main.async {
                    self.workoutCalories = calories
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

// MARK: - WKExtendedRuntimeSessionDelegate
extension WorkoutManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        print("Extended runtime session invalidated: \(reason)")
        // 세션이 무효화되면 새로운 세션 시작
        startExtendedRuntimeSession()
    }
    
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session started")
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session will expire")
    }
}
