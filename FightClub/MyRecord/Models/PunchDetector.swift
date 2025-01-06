import Vision
import CoreGraphics
import QuartzCore

class PunchDetector {
    // MARK: - Properties
    private var lastPunchTime: Date?
    private let minimumInterval: TimeInterval = 0.8 // 연속 펀치 사이의 최소 간격을 0.8초로 증가
    private var previousWristPositions: [VNHumanBodyPoseObservation.JointName: (position: CGPoint, time: Date)] = [:]
    private var lastPunchHand: VNHumanBodyPoseObservation.JointName?
    
    func detectPunch(in sampleBuffer: CMSampleBuffer, completion: @escaping (Bool) -> Void) {
        // 최소 시간 간격 체크
        if let lastPunch = lastPunchTime {
            let timeSinceLastPunch = Date().timeIntervalSince(lastPunch)
            guard timeSinceLastPunch >= minimumInterval else { return }
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error detecting body pose: \(error)")
                return
            }
            
            guard let observation = request.results?.first as? VNHumanBodyPoseObservation else { return }
            
            // 팔 관절 위치 추출
            guard let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
                  let rightElbow = try? observation.recognizedPoint(.rightElbow),
                  let rightWrist = try? observation.recognizedPoint(.rightWrist),
                  let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
                  let leftElbow = try? observation.recognizedPoint(.leftElbow),
                  let leftWrist = try? observation.recognizedPoint(.leftWrist) else {
                return
            }
            
            // 신뢰도 체크
            let confidenceThreshold: Float = 0.3
            guard rightShoulder.confidence > confidenceThreshold &&
                  rightElbow.confidence > confidenceThreshold &&
                  rightWrist.confidence > confidenceThreshold &&
                  leftShoulder.confidence > confidenceThreshold &&
                  leftElbow.confidence > confidenceThreshold &&
                  leftWrist.confidence > confidenceThreshold else {
                return
            }
            
            let currentTime = Date()
            
            // 마지막으로 감지된 손과 다른 손의 펀치만 우선 확인
            var detectedPunch = false
            
            if self.lastPunchHand != .rightWrist {
                // 오른손 펀치 확인
                if self.detectPunchMotion(shoulder: rightShoulder,
                                        elbow: rightElbow,
                                        wrist: rightWrist,
                                        jointName: .rightWrist,
                                        currentTime: currentTime) {
                    detectedPunch = true
                    self.lastPunchHand = .rightWrist
                }
            }
            
            if !detectedPunch && self.lastPunchHand != .leftWrist {
                // 왼손 펀치 확인
                if self.detectPunchMotion(shoulder: leftShoulder,
                                        elbow: leftElbow,
                                        wrist: leftWrist,
                                        jointName: .leftWrist,
                                        currentTime: currentTime) {
                    detectedPunch = true
                    self.lastPunchHand = .leftWrist
                }
            }
            
            if detectedPunch {
                self.lastPunchTime = currentTime
                DispatchQueue.main.async {
                    completion(true)
                }
            }
            
            // 현재 손목 위치 저장
            self.previousWristPositions[.rightWrist] = (rightWrist.location, currentTime)
            self.previousWristPositions[.leftWrist] = (leftWrist.location, currentTime)
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])
    }
    
    private func detectPunchMotion(shoulder: VNRecognizedPoint,
                                 elbow: VNRecognizedPoint,
                                 wrist: VNRecognizedPoint,
                                 jointName: VNHumanBodyPoseObservation.JointName,
                                 currentTime: Date) -> Bool {
        // 팔 각도 계산
        let shoulderToElbowAngle = calculateAngle(shoulder, elbow)
        let elbowToWristAngle = calculateAngle(elbow, wrist)
        
        // 팔이 펴진 상태인지 확인 (어깨-팔꿈치-손목이 일직선에 가까운지)
        let angleThreshold: Float = 30.0 // 각도 차이 허용 범위
        let isArmExtended = abs(shoulderToElbowAngle - elbowToWristAngle) < angleThreshold
        
        // 손목이 어깨보다 앞에 있는지 확인 (펀치 동작)
        let isWristForward = wrist.x > shoulder.x
        
        // 손목 이동 속도 계산
        if let previousData = previousWristPositions[jointName] {
            let previousPosition = previousData.position
            let previousTime = previousData.time
            
            let dx = wrist.location.x - previousPosition.x
            let dy = wrist.location.y - previousPosition.y
            let distance = sqrt(dx * dx + dy * dy)
            
            let timeInterval = currentTime.timeIntervalSince(previousTime)
            let speed = distance / CGFloat(timeInterval)
            
            // 속도가 임계값보다 높을 때만 펀치로 인정
            let speedThreshold: CGFloat = 1.5 // 속도 임계값 증가
            let isSpeedSufficient = speed > speedThreshold
            
            return isArmExtended && isWristForward && isSpeedSufficient
        }
        
        return false
    }
    
    private func calculateAngle(_ point1: VNRecognizedPoint, _ point2: VNRecognizedPoint) -> Float {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return Float(atan2(dy, dx) * 180 / .pi)
    }
} 
