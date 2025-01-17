import HealthKit
import WatchConnectivity

class HealthKitManager: NSObject, ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKQuery?
    private var caloriesQuery: HKQuery?
    private var updateTimer: Timer?
    
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var isRecording = false
    @Published var workoutCalories: Double = 0
    @Published var maxPunchSpeed: Double = 0.0
    @Published var avgPunchSpeed: Double = 0.0
    @Published var isWorkoutActive: Bool = false
    
    private let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    private let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    
    override init() {
        super.init()
        requestAuthorization()
        setupNotifications()
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
            selector: #selector(handleWatchContextNotification(_:)),
            name: .watchContextReceived,
            object: nil
        )
    }
    
    @objc private func handleWatchMessage(_ notification: Notification) {
        guard let message = notification.userInfo as? [String: Any] else { return }
        print("수신됨? 메세지", message)
        DispatchQueue.main.async {
            if let heartRate = message["heartRate"] as? Double {
                self.heartRate = heartRate
            }
            if let calories = message["calories"] as? Double {
                self.activeCalories = calories
            }
            if let maxSpeed = message["maxPunchSpeed"] as? Double {
                self.maxPunchSpeed = maxSpeed
            }
            if let avgSpeed = message["avgPunchSpeed"] as? Double {
                self.avgPunchSpeed = avgSpeed
            }
        }
    }
    
    @objc private func handleWatchContextNotification(_ notification: Notification) {
        guard let context = notification.userInfo as? [String: Any] else { return }
        handleWatchContext(context)
    }
    
    private func handleWatchContext(_ context: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let type = context["type"] as? String {
                switch type {
                case "heartRateUpdate":
                    if let heartRate = context["heartRate"] as? Double {
                        self.heartRate = heartRate
                    }
                case "punchStats":
                    print("PUNCHSTATS", context)
                    if let maxSpeed = context["maxSpeed"] as? Double {
                        self.maxPunchSpeed = maxSpeed
                    }
                    
                    if let avgSpeed = context["avgSpeed"] as? Double {
                        self.avgPunchSpeed = avgSpeed
                    }
                case "workout":
                    if let command = context["command"] as? String {
                        self.handleWorkoutCommand(command)
                    }
                case "healthData":
                    if let heartRate = context["heartRate"] as? Double {
                        self.heartRate = heartRate
                    }
                    if let calories = context["calories"] as? Double {
                        self.activeCalories = calories
                    }
                    if let workoutCalories = context["workoutCalories"] as? Double {
                        self.workoutCalories = workoutCalories
                    }
                default:
                    print("알 수 없는 메시지 타입: \(type), \(context)")
                }
            } else {
                // 이전 형식의 컨텍스트 처리
                if let heartRate = context["heartRate"] as? Double {
                    self.heartRate = heartRate
                }
                if let calories = context["calories"] as? Double {
                    self.activeCalories = calories
                }
                if let workoutCalories = context["workoutCalories"] as? Double {
                    self.workoutCalories = workoutCalories
                }
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
    
    // MARK: - Workout Session Management
    func startWorkoutSession() {
        let message: [String: Any] = [
            "command": "startWorkout",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WatchConnectivityManager.shared.sendMessage(message) { [weak self] reply in
            if let status = reply["status"] as? String, status == "started" {
                DispatchQueue.main.async {
                    self?.isRecording = true
                }
            }
        }
    }
    
    func stopWorkoutSession() {
        let message: [String: Any] = [
            "command": "stopWorkout",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WatchConnectivityManager.shared.sendMessage(message) { [weak self] reply in
            if let status = reply["status"] as? String, status == "stopped" {
                DispatchQueue.main.async {
                    self?.isRecording = false
                    self?.stopHealthMonitoring()
                }
            }
        }
    }
    
    private func stopHealthMonitoring() {
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
    
    private func startHeartRateMonitoring() {
        print("심박수 모니터링 시작")
        
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processHeartRateSamples(samples as? [HKQuantitySample])
        }
        
        query.updateHandler = { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processHeartRateSamples(samples as? [HKQuantitySample])
        }
        
        heartRateQuery = query
        healthStore.execute(query)
    }
    
    private func startCaloriesMonitoring() {
        print("칼로리 모니터링 시작")
        
        if let query = caloriesQuery {
            healthStore.stop(query)
        }
        
        let query = HKAnchoredObjectQuery(
            type: activeEnergyType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processCaloriesSamples(samples as? [HKQuantitySample])
        }
        
        query.updateHandler = { [weak self] (query, samples, deletedObjects, anchor, error) in
            self?.processCaloriesSamples(samples as? [HKQuantitySample])
        }
        
        caloriesQuery = query
        healthStore.execute(query)
    }
    
    private func processHeartRateSamples(_ samples: [HKQuantitySample]?) {
        guard let samples = samples, let mostRecentSample = samples.first else { return }
        
        DispatchQueue.main.async {
            let heartRate = mostRecentSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            self.heartRate = heartRate
        }
    }
    
    private func processCaloriesSamples(_ samples: [HKQuantitySample]?) {
        guard let samples = samples else { return }
        
        DispatchQueue.main.async {
            let calories = samples.reduce(0.0) { sum, sample in
                sum + sample.quantity.doubleValue(for: HKUnit.kilocalorie())
            }
            self.activeCalories = calories
        }
    }
    
    func checkWorkoutStatus() {
        let message: [String: Any] = [
            "command": "status",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WatchConnectivityManager.shared.sendMessage(message) { [weak self] reply in
            if let status = reply["workoutStatus"] as? String {
                DispatchQueue.main.async {
                    self?.isRecording = (status == "active")
                }
            }
        }
    }
    
    private func handleWorkoutCommand(_ command: String) {
        DispatchQueue.main.async {
            switch command {
            case "startWorkout":
                print("운동 시작 명령 수신")
                self.isWorkoutActive = true
                self.startWorkout()
                
            case "stopWorkout":
                print("운동 종료 명령 수신")
                self.isWorkoutActive = false
                self.stopWorkout()
                
            default:
                print("알 수 없는 운동 명령: \(command)")
            }
        }
    }
    
    private func startWorkout() {
        // 운동 시작 시 초기화
        maxPunchSpeed = 0.0
        avgPunchSpeed = 0.0
        heartRate = 0.0
        
        // 워치에 운동 시작 명령 전송
        let message: [String: Any] = [
            "type": "workout",
            "command": "startWorkout",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WatchConnectivityManager.shared.sendMessage(message)
        print("워치에 운동 시작 명령 전송")
    }
    
    private func stopWorkout() {
        // 워치에 운동 종료 명령 전송
        let message: [String: Any] = [
            "type": "workout",
            "command": "stopWorkout",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WatchConnectivityManager.shared.sendMessage(message)
        print("워치에 운동 종료 명령 전송")
        
        // 최종 데이터 저장 또는 처리
        // TODO: 운동 데이터 저장 로직 추가
    }
}
