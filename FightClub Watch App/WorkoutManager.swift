import WatchConnectivity
import HealthKit

class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()
    
    // MARK: - Published Properties
    @Published var isWorkoutActive = false
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    
    // MARK: - Private Properties
    private var healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private let connectivityManager = WatchConnectivityManager.shared
    private let punchMotionManager = PunchMotionManager.shared
    
    private override init() {
        super.init()
        requestAuthorization()
    }
    
    // MARK: - HealthKit Authorization
    private func requestAuthorization() {
        let typesToShare: Set = [HKQuantityType.workoutType()]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            if success {
                print("HealthKit 권한 요청 성공")
                DispatchQueue.main.async {
                    self?.setupHealthKitObservers()
                }
            } else if let error = error {
                print("HealthKit 권한 요청 실패: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Workout Control
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
            builder?.beginCollection(withStart: Date()) { [weak self] (success, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("운동 데이터 수집 시작 실패: \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.main.async {
                    self.isWorkoutActive = true
                    self.punchMotionManager.startMonitoring()
                    self.startDataUpdateTimer()  // 데이터 업데이트 타이머 시작
                    print("워크아웃 및 펀치 모니터링 시작")
                }
            }
        } catch {
            print("운동 세션 생성 실패: \(error.localizedDescription)")
        }
    }
    
    func stopWorkout() {
        stopDataUpdateTimer()  // 데이터 업데이트 타이머 중지
        punchMotionManager.stopMonitoring()
        session?.end()
        
        builder?.endCollection(withEnd: Date()) { [weak self] (success, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("운동 데이터 수집 종료 실패: \(error.localizedDescription)")
                return
            }
            
            self.builder?.finishWorkout { (workout, error) in
                DispatchQueue.main.async {
                    self.isWorkoutActive = false
                    print("워크아웃 및 펀치 모니터링 종료")
                }
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
        
        // command 키가 있는 경우 워크아웃 명령으로 처리
        if let command = message["command"] as? String {
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
            return
        }
        
        // type 키가 있는 경우 데이터 메시지로 처리
        if let type = message["type"] as? String {
            switch type {
            case "punchData":
                if let speed = message["speed"] as? Double {
                    handlePunchData(speed)
                }
            default:
                print("알 수 없는 메시지 타입: \(type)")
            }
        }
    }
    
    // MARK: - HealthKit Observers
    private func setupHealthKitObservers() {
        setupHeartRateObserver()
        setupCaloriesObserver()
    }
    
    private func setupHeartRateObserver() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Heart rate observer error: \(error)")
                return
            }
            self?.fetchLatestHeartRate()
        }
        
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { _, error in
            if let error = error {
                print("Failed to enable background delivery for heart rate: \(error)")
            }
        }
    }
    
    private func setupCaloriesObserver() {
        guard let caloriesType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let query = HKObserverQuery(sampleType: caloriesType, predicate: nil) { [weak self] _, _, error in
            if let error = error {
                print("Calories observer error: \(error)")
                return
            }
            self?.fetchLatestCalories()
        }
        
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: caloriesType, frequency: .immediate) { _, error in
            if let error = error {
                print("Failed to enable background delivery for calories: \(error)")
            }
        }
    }
    
    private func fetchLatestHeartRate() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-10), end: nil, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            DispatchQueue.main.async {
                let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                self?.heartRate = heartRate
                self?.connectivityManager.sendHeartRate(heartRate)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func fetchLatestCalories() {
        guard let caloriesType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-10), end: nil, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: caloriesType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            
            DispatchQueue.main.async {
                let calories = sample.quantity.doubleValue(for: HKUnit.kilocalorie())
                self?.activeCalories = calories
                self?.connectivityManager.sendCalories(calories)
            }
        }
        
        healthStore.execute(query)
    }
    
    deinit {
        punchMotionManager.stopMonitoring()
    }
    
    // MARK: - Data Updates
    private func updateAndSendHealthData() {
        // 심박수 데이터 전송
        if let heartRate = builder?.statistics(for: HKQuantityType(.heartRate))?.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) {
            print("심박수 업데이트: \(heartRate) BPM")
            connectivityManager.sendHeartRate(heartRate)
        }
        
        // 칼로리 데이터 전송
        if let calories = builder?.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
            print("칼로리 업데이트: \(calories) kcal")
            connectivityManager.sendCalories(calories)
        }
    }
    
    // MARK: - Motion Updates
    func processPunchMotion(speed: Double) {
        currentPunchSpeed = speed
        
        // 최대 속도 업데이트
        if speed > maxPunchSpeed {
            maxPunchSpeed = speed
            // 최대 속도 갱신 시 전송
            connectivityManager.sendPunchData(speed: speed, isMax: true)
        }
        
        // 평균 속도 계산 및 업데이트
        totalPunchSpeed += speed
        punchCount += 1
        avgPunchSpeed = totalPunchSpeed / Double(punchCount)
        
        // 현재 펀치 데이터 전송
        connectivityManager.sendPunchData(speed: speed)
        
        print("펀치 감지 - 속도: \(speed) m/s, 최대: \(maxPunchSpeed) m/s, 평균: \(avgPunchSpeed) m/s")
    }
    
    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                print("워크아웃 세션 시작")
                self.connectivityManager.sendWorkoutStarted()
                // 데이터 업데이트 타이머 시작
                self.startDataUpdateTimer()
            case .ended:
                print("워크아웃 세션 종료")
                self.connectivityManager.sendWorkoutEnded()
                // 타이머 정지
                self.stopDataUpdateTimer()
            default:
                print("워크아웃 세션 상태 변경: \(toState.rawValue)")
            }
        }
    }
    
    // MARK: - Update Timer
    private var updateTimer: Timer?
    
    private func startDataUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateAndSendHealthData()
        }
    }
    
    private func stopDataUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            switch quantityType.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                let statistics = workoutBuilder.statistics(for: quantityType)
                let heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0
                DispatchQueue.main.async {
                    self.heartRate = heartRate
                    self.connectivityManager.sendHeartRate(heartRate)
                }
                
            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                let statistics = workoutBuilder.statistics(for: quantityType)
                let calories = statistics?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                DispatchQueue.main.async {
                    self.activeCalories = calories
                    self.connectivityManager.sendCalories(calories)
                }
                
            default:
                break
            }
        }
    }
} } 
