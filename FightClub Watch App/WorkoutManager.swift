import Foundation
import HealthKit
import WatchConnectivity

class WorkoutManager: NSObject, ObservableObject, HKLiveWorkoutBuilderDelegate {
    static let shared = WorkoutManager()
    
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var wcSession: WCSession?
    
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var isWorkoutInProgress = false
    
    // 운동 타입 설정
    private let workoutType = HKWorkoutActivityType.boxing
    
    override init() {
        super.init()
        
        // Watch Connectivity 설정
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }
        
        // HealthKit 권한 요청
        requestAuthorization()
    }
    
    func requestAuthorization() {
        // 읽기 권한이 필요한 데이터 타입
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        // 쓰기 권한이 필요한 데이터 타입
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if success {
                print("HealthKit 권한 획득 성공")
            } else if let error = error {
                print("HealthKit 권한 획득 실패: \(error.localizedDescription)")
            }
        }
    }
    
    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType
        configuration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            
            // 데이터 수집 설정
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                        workoutConfiguration: configuration)
            
            // 세션 시작
            let startDate = Date()
            session?.startActivity(with: startDate)
            builder?.beginCollection(withStart: startDate) { success, error in
                if success {
                    self.isWorkoutInProgress = true
                    self.startDataCollection()
                }
            }
        } catch {
            print("워크아웃 세션 생성 실패: \(error.localizedDescription)")
        }
    }
    
    func stopWorkout() {
        session?.end()
        builder?.endCollection(withEnd: Date()) { success, error in
            self.builder?.finishWorkout { workout, error in
                self.isWorkoutInProgress = false
                self.session = nil
                self.builder = nil
            }
        }
    }
    
    private func startDataCollection() {
        // 데이터 수집 설정
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let caloriesType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        // 데이터 수집 시작
        builder?.dataSource?.enableCollection(for: heartRateType, predicate: nil)
        builder?.dataSource?.enableCollection(for: caloriesType, predicate: nil)
        
        // 델리게이트 설정
        builder?.delegate = self
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            DispatchQueue.main.async {
                switch statistics?.quantityType {
                case HKQuantityType.quantityType(forIdentifier: .heartRate):
                    let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
                    self.heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                    self.sendDataToPhone()
                    
                case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
                    let energyUnit = HKUnit.kilocalorie()
                    self.activeCalories = statistics?.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
                    self.sendDataToPhone()
                    
                default:
                    return
                }
            }
        }
    }
    
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // 이벤트 수집 처리 (필요한 경우)
    }
    
    // 에러 처리
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didFinishWith workout: HKWorkout?, error: Error?) {
        if let error = error {
            print("Workout Builder Error: \(error.localizedDescription)")
        }
    }
    
    private func sendDataToPhone() {
        let message = [
            "heartRate": heartRate,
            "calories": activeCalories
        ]
        
        wcSession?.sendMessage(message, replyHandler: nil) { error in
            print("데이터 전송 실패: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate
extension WorkoutManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession 활성화 실패: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let command = message["command"] as? String {
                switch command {
                case "startWorkout":
                    self.startWorkout()
                case "stopWorkout":
                    self.stopWorkout()
                default:
                    break
                }
            }
        }
    }
} 