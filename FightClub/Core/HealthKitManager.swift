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
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        requestAuthorization()
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
    
    func startWorkoutSession() {
        isRecording = true
        // Watch에 운동 시작 알림
        session?.sendMessage(["command": "startWorkout"], replyHandler: nil) { error in
            print("워치 통신 에러: \(error.localizedDescription)")
        }
    }
    
    func stopWorkoutSession() {
        isRecording = false
        // Watch에 운동 종료 알림
        session?.sendMessage(["command": "stopWorkout"], replyHandler: nil) { error in
            print("워치 통신 에러: \(error.localizedDescription)")
        }
    }
}

// WatchConnectivity 델리게이트 구현
extension HealthKitManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession 활성화 실패: \(error.localizedDescription)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    
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
} 