import Foundation
import CoreMotion

class PunchMotionManager: ObservableObject {
    static let shared = PunchMotionManager()
    
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private let workoutManager = WorkoutManager.shared
    
    private init() {
        queue.name = "PunchMotionQueue"
    }
    
    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else {
            print("가속도계를 사용할 수 없습니다")
            return
        }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: queue) { [weak self] (data, error) in
            guard let data = data else {
                if let error = error {
                    print("가속도계 오류: \(error.localizedDescription)")
                }
                return
            }
            
            // 펀치 감지 및 속도 계산
            let acceleration = sqrt(pow(data.acceleration.x, 2) + 
                                 pow(data.acceleration.y, 2) + 
                                 pow(data.acceleration.z, 2))
            
            // 가속도를 속도로 변환 (m/s)
            let speed = acceleration * 9.81
            
            // 임계값 이상의 속도일 때 펀치로 인식
            if speed > 5.0 {  // 임계값 조정 가능
                DispatchQueue.main.async {
                    self?.workoutManager.processPunchMotion(speed: speed)
                }
            }
        }
        print("펀치 모션 모니터링 시작")
    }
    
    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
        print("펀치 모션 모니터링 종료")
    }
} 