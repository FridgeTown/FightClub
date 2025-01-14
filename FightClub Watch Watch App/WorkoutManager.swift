import Foundation
import WatchConnectivity
import HealthKit

class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()
    private var session: WCSession?
    private let healthStore = HKHealthStore()
    
    @Published var isWorkoutInProgress = false
    @Published var heartRate: Double = 0
    @Published var activeCalories: Double = 0
    
    // 쿼리를 저장할 프로퍼티
       private var heartRateQuery: HKQuery?
       private var energyQuery: HKQuery?
    
    override init() {
        super.init()
        setupWatchConnectivity()
    }
    
    // 초기화 및 권한 요청
       func requestAuthorization() {
           // 심박수와 활동 에너지 타입
           let typesToRead: Set = [
               HKQuantityType.quantityType(forIdentifier: .heartRate)!,
               HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
           ]
           
           // 권한 요청
           healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
               if success {
                   self.startHeartRateMonitoring()
                   self.startEnergyMonitoring()
               }
           }
       }
       
       // 심박수 모니터링 시작
       private func startHeartRateMonitoring() {
           let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
           
           // 쿼리 설정
           let query = HKAnchoredObjectQuery(
               type: heartRateType,
               predicate: nil,
               anchor: nil,
               limit: HKObjectQueryNoLimit
           ) { [weak self] query, samples, deletedObjects, anchor, error in
               // 초기 데이터 처리
           }
           
           // 실시간 업데이트를 위한 설정
           query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
               guard let samples = samples as? [HKQuantitySample] else { return }
               
               DispatchQueue.main.async {
                   // 가장 최근 심박수 가져오기
                   if let mostRecentSample = samples.last {
                       let heartRate = mostRecentSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                       self?.heartRate = heartRate
                       print("현재 심박수: \(heartRate) BPM")
                   }
               }
           }
           
           healthStore.execute(query)
           heartRateQuery = query
       }
       
       // 칼로리 소모량 모니터링 시작
       private func startEnergyMonitoring() {
           let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
           
           // 쿼리 설정
           let query = HKAnchoredObjectQuery(
               type: energyType,
               predicate: nil,
               anchor: nil,
               limit: HKObjectQueryNoLimit
           ) { [weak self] query, samples, deletedObjects, anchor, error in
               // 초기 데이터 처리
           }
           
           // 실시간 업데이트를 위한 설정
           query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
               guard let samples = samples as? [HKQuantitySample] else { return }
               
               DispatchQueue.main.async {
                   // 가장 최근 칼로리 소모량 가져오기
                   if let mostRecentSample = samples.last {
                       let calories = mostRecentSample.quantity.doubleValue(for: HKUnit.kilocalorie())
                       self?.activeCalories = calories
                       print("소모 칼로리: \(calories) kcal")
                   }
               }
           }
           
           healthStore.execute(query)
           energyQuery = query
       }
       
       // 모니터링 중지
       func stopMonitoring() {
           if let heartRateQuery = heartRateQuery {
               healthStore.stop(heartRateQuery)
           }
           if let energyQuery = energyQuery {
               healthStore.stop(energyQuery)
           }
       }
    
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            self.session = session
            
            print("\n=== Watch 앱 WCSession 설정 ===")
            print("Watch 앱 번들 ID: \(Bundle.main.bundleIdentifier ?? "없음")")
            
            // 초기 컨텍스트 설정
            do {
                let initialContext = ["status": "ready",
                                    "timestamp": Date().timeIntervalSince1970] as [String: Any]
                try session.updateApplicationContext(initialContext)
            } catch {
                print("초기 컨텍스트 설정 실패: \(error.localizedDescription)")
            }
        }
    }
    
    // 운동 세션 시작
    func startWorkout() {
        isWorkoutInProgress = true
        // 여기에 실제 운동 세션 시작 코드 추가
        requestAuthorization()
        // iOS 앱에 상태 알림
        sendMessageToiOS(["status": "workoutStarted",
                         "timestamp": Date().timeIntervalSince1970])
    }
    
    // 운동 세션 종료
    func stopWorkout() {
        isWorkoutInProgress = false
        // 여기에 실제 운동 세션 종료 코드 추가
        stopMonitoring()
        // iOS 앱에 상태 알림
        sendMessageToiOS(["status": "workoutEnded",
                         "timestamp": Date().timeIntervalSince1970])
    }
    
    // iOS 앱으로 메시지 전송
    private func sendMessageToiOS(_ message: [String: Any]) {
        guard let session = session, session.isReachable else {
            print("iOS 앱과 통신할 수 없음")
            // 백그라운드 전송 시도
            do {
                try session?.updateApplicationContext(message)
                print("백그라운드 메시지 전송 성공")
            } catch {
                print("백그라운드 메시지 전송 실패: \(error.localizedDescription)")
            }
            return
        }
        
        session.sendMessage(message, replyHandler: { reply in
            print("iOS 앱 응답: \(reply)")
        }, errorHandler: { error in
            print("메시지 전송 실패: \(error.localizedDescription)")
            // 실패 시 백그라운드 전송 시도
            do {
                try session.updateApplicationContext(message)
                print("백그라운드 메시지 전송 성공")
            } catch {
                print("백그라운드 메시지 전송 실패: \(error.localizedDescription)")
            }
        })
    }
}

// MARK: - WCSessionDelegate
extension WorkoutManager: WCSessionDelegate {
    func session(_ session: WCSession,
                activationDidCompleteWith activationState: WCSessionActivationState,
                error: Error?) {
        DispatchQueue.main.async {
            print("\n=== Watch WCSession 활성화 ===")
            print("활성화 상태: \(activationState.rawValue)")
            print("통신 가능: \(session.isReachable)")
            
            if let error = error {
                print("활성화 오류: \(error.localizedDescription)")
            }
        }
    }
    
    // iOS 앱으로부터 메시지 수신
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            if let command = message["command"] as? String {
                switch command {
                case "startWorkout":
                    self.startWorkout()
                    replyHandler(["status": "started",
                                "timestamp": Date().timeIntervalSince1970])
                    
                case "stopWorkout":
                    self.stopWorkout()
                    replyHandler(["status": "stopped",
                                "timestamp": Date().timeIntervalSince1970])
                    
                case "status":
                    replyHandler(["status": self.isWorkoutInProgress ? "active" : "inactive",
                                "heartRate": self.heartRate,
                                "calories": self.activeCalories,
                                "timestamp": Date().timeIntervalSince1970])
                    
                default:
                    replyHandler(["error": "Unknown command"])
                }
            } else {
                replyHandler(["error": "Invalid message format"])
            }
        }
    }
    
    // 백그라운드 메시지 수신
    func session(_ session: WCSession,
                didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            if let command = applicationContext["command"] as? String {
                switch command {
                case "startWorkout":
                    self.startWorkout()
                case "stopWorkout":
                    self.stopWorkout()
                default:
                    print("알 수 없는 백그라운드 명령: \(command)")
                }
            }
        }
    }
    
    // 연결 상태 변경
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            print("통신 상태 변경: \(session.isReachable)")
            
            if session.isReachable {
                // 연결되면 현재 상태 전송
                self.sendMessageToiOS([
                    "status": self.isWorkoutInProgress ? "active" : "inactive",
                    "heartRate": self.heartRate,
                    "calories": self.activeCalories,
                    "timestamp": Date().timeIntervalSince1970
                ])
            }
        }
    }
}
