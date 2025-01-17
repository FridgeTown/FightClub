import Foundation
import CoreMotion
import WatchConnectivity
import HealthKit

class PunchMotionManager: NSObject, WCSessionDelegate {
    static let shared = PunchMotionManager()
    
    private let motionManager = CMMotionManager()
    private let healthStore = HKHealthStore()
    private var session: WCSession?
    private var isMonitoring = false
    
    // 심박수 관련
    private var heartRateQuery: HKQuery?
    @Published var currentHeartRate: Double = 0
    
    override private init() {
        super.init()
        setupWatchSession()
        setupHealthKit()
    }
    
    private func setupWatchSession() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    private func setupHealthKit() {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let typesToRead: Set = [heartRateType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                self.startHeartRateMonitoring()
            } else if let error = error {
                print("HealthKit authorization failed: \(error)")
            }
        }
    }
    
    private func startHeartRateMonitoring() {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: nil, options: .strictEndDate)
        
        heartRateQuery = HKAnchoredObjectQuery(type: heartRateType,
                                             predicate: predicate,
                                             anchor: nil,
                                             limit: HKObjectQueryNoLimit) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }
        
        if let query = heartRateQuery {
            healthStore.execute(query)
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }
        
        for sample in samples {
            let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            currentHeartRate = heartRate
            sendHeartRate(heartRate)
        }
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer is not available")
            return
        }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            
            // 가속도 크기 계산
            let magnitude = sqrt(pow(data.acceleration.x, 2) +
                              pow(data.acceleration.y, 2) +
                              pow(data.acceleration.z, 2))
            
            // 펀치 감지 임계값 (조정 가능)
            let threshold: Double = 2.5
            if magnitude > threshold {
                self?.sendPunchData(magnitude: magnitude)
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        motionManager.stopAccelerometerUpdates()
        heartRateQuery = nil
    }
    
    private func sendPunchData(magnitude: Double) {
        guard let session = session, session.isReachable else { return }
        
        let data: [String: Any] = [
            "punchMagnitude": magnitude,
            "heartRate": currentHeartRate
        ]
        
        session.sendMessage(data, replyHandler: nil) { error in
            print("Failed to send punch data: \(error)")
        }
    }
    
    private func sendHeartRate(_ heartRate: Double) {
        guard let session = session, session.isReachable else { return }
        
        let data: [String: Any] = ["heartRate": heartRate]
        session.sendMessage(data, replyHandler: nil) { error in
            print("Failed to send heart rate: \(error)")
        }
    }
    
    // MARK: - WCSession Delegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Watch session activation completed: \(activationState.rawValue)")
    }
} 