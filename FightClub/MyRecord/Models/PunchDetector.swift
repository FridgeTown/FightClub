import Vision
import CoreGraphics
import QuartzCore

class PunchDetector {
    // MARK: - Properties
    private var lastPunchTime: TimeInterval = 0
    private let minimumPunchInterval: TimeInterval = 0.2
    private var previousPositions: [PosePositions] = []
    private var punchCount: Int = 0
    
    /// 펀치 감지 콜백
    var onPunchDetected: ((Int) -> Void)?
    
    // MARK: - Constants
    private enum Constants {
        static let confidenceThreshold: Float = 0.2
        
        // 펀치 관련 상수
        static let jabExtensionThreshold: CGFloat = 0.25  // 잽 거리
        static let punchExtensionThreshold: CGFloat = 0.2  // 일반 펀치 거리
        static let sidePunchExtensionThreshold: CGFloat = 0.25  // 측면 펀치 거리
        
        // 자세 관련 상수
        static let jabElbowAngle: CGFloat = 150  // 잽의 팔꿈치 각도
        static let punchElbowAngleMin: CGFloat = 90  // 일반 펀치 최소 각도
        static let punchElbowAngleMax: CGFloat = 170  // 일반 펀치 최대 각도
        static let sidePunchElbowAngle: CGFloat = 120  // 측면 펀치 각도
        
        // 높이 관련 상수
        static let heightThreshold: CGFloat = 0.2
        static let guardHeightThreshold: CGFloat = 0.2
        static let guardDistanceThreshold: CGFloat = 0.1
        
        // 회전 관련 상수
        static let frontAngleThreshold: CGFloat = 30
    }
    
    // MARK: - Stance Direction
    private enum StanceDirection {
        case front
        case left
        case right
    }
    
    // MARK: - Public Methods
    func detectPunch(from observation: VNHumanBodyPoseObservation) -> Bool {
        // 1. 키포인트 추출 및 검증
        guard let keypoints = try? observation.recognizedPoints(.all),
              let positions = extractValidPositions(from: keypoints) else {
            return false
        }
        
        // 2. 시간 간격 체크
        let currentTime = CACurrentMediaTime()
        let timeSinceLastPunch = currentTime - lastPunchTime
        guard timeSinceLastPunch >= minimumPunchInterval else { return false }
        
        // 3. 가드 자세 체크
        if isGuardPosition(positions) {
            return false
        }
        
        // 4. 상체 회전 각도 계산
        let torsoAngle = calculateTorsoAngle(positions)
        
        // 5. 방향에 따른 펀치 감지
        var isPunch = false
        if abs(torsoAngle) < Constants.frontAngleThreshold {
            isPunch = detectFrontPunch(positions)
        } else if torsoAngle > Constants.frontAngleThreshold {
            isPunch = detectSidePunch(positions, isLeftSide: true)
        } else {
            isPunch = detectSidePunch(positions, isLeftSide: false)
        }
        
        if isPunch {
            lastPunchTime = currentTime
            punchCount += 1
            print("펀치 감지! 현재 카운트: \(punchCount)")
            onPunchDetected?(punchCount)
        }
        
        return isPunch
    }
    
    // MARK: - Private Methods
    private func isGuardPosition(_ positions: PosePositions) -> Bool {
        // 양손이 어깨 높이보다 높은지 확인
        let handsAboveShoulders = positions.leftWrist.y < positions.leftShoulder.y &&
                                 positions.rightWrist.y < positions.rightShoulder.y
        
        // 양손이 얼굴 근처에 있는지 확인
        let handsNearFace = abs(positions.leftWrist.x - positions.nose.x) < 0.25 &&
                           abs(positions.rightWrist.x - positions.nose.x) < 0.25
        
        // 팔꿈치가 구부러져 있는지 확인
        let elbowsBent = calculateElbowAngle(positions.leftShoulder, positions.leftElbow, positions.leftWrist) < 120 &&
                        calculateElbowAngle(positions.rightShoulder, positions.rightElbow, positions.rightWrist) < 120
        
        return handsAboveShoulders && handsNearFace && elbowsBent
    }
    
    private func calculateTorsoAngle(_ positions: PosePositions) -> CGFloat {
        let shoulderVector = CGPoint(
            x: positions.rightShoulder.x - positions.leftShoulder.x,
            y: positions.rightShoulder.y - positions.leftShoulder.y
        )
        
        return atan2(shoulderVector.y, shoulderVector.x) * 180 / .pi
    }
    
    private func detectFrontPunch(_ positions: PosePositions) -> Bool {
        // 잽 (왼손 스트레이트) 감지
        let isJab = checkJabConditions(
            wrist: positions.leftWrist,
            elbow: positions.leftElbow,
            shoulder: positions.leftShoulder,
            nose: positions.nose,
            otherWrist: positions.rightWrist
        )
        
        // 일반 펀치 감지
        let leftPunch = checkPunchConditions(
            wrist: positions.leftWrist,
            elbow: positions.leftElbow,
            shoulder: positions.leftShoulder,
            nose: positions.nose,
            isLeft: true
        )
        
        let rightPunch = checkPunchConditions(
            wrist: positions.rightWrist,
            elbow: positions.rightElbow,
            shoulder: positions.rightShoulder,
            nose: positions.nose,
            isLeft: false
        )
        
        return isJab || leftPunch || rightPunch
    }
    
    private func checkJabConditions(
        wrist: CGPoint,
        elbow: CGPoint,
        shoulder: CGPoint,
        nose: CGPoint,
        otherWrist: CGPoint
    ) -> Bool {
        // 1. 왼손 위치 확인 (빠르고 직선적인 움직임)
        let punchExtension = abs(wrist.x - shoulder.x)
        let isJabExtension = punchExtension > Constants.jabExtensionThreshold
        
        // 2. 팔꿈치 각도 확인 (잽은 더 폄)
        let elbowAngle = calculateElbowAngle(shoulder, elbow, wrist)
        let isProperElbowAngle = elbowAngle > Constants.jabElbowAngle
        
        // 3. 손목 높이 확인 (얼굴 높이)
        let isProperHeight = abs(wrist.y - nose.y) < Constants.heightThreshold
        
        // 4. 오른손(가드 손) 위치 확인
        let isGuardHandProper = otherWrist.x < nose.x + Constants.guardDistanceThreshold &&
                               abs(otherWrist.y - nose.y) < Constants.guardHeightThreshold
        
        return isJabExtension && isProperElbowAngle && isProperHeight && isGuardHandProper
    }
    
    private func checkPunchConditions(
        wrist: CGPoint,
        elbow: CGPoint,
        shoulder: CGPoint,
        nose: CGPoint,
        isLeft: Bool
    ) -> Bool {
        // 1. 손목 위치 확인
        let punchExtension = abs(wrist.x - shoulder.x)
        let isPunchingForward = punchExtension > Constants.punchExtensionThreshold
        
        // 2. 팔꿈치 각도 확인
        let elbowAngle = calculateElbowAngle(shoulder, elbow, wrist)
        let isProperElbowAngle = elbowAngle > Constants.punchElbowAngleMin &&
                                elbowAngle < Constants.punchElbowAngleMax
        
        // 3. 손목 높이 확인
        let isProperHeight = wrist.y >= shoulder.y - 0.3 && wrist.y <= nose.y + 0.2
        
        return isPunchingForward && isProperElbowAngle && isProperHeight
    }
    
    private func detectSidePunch(_ positions: PosePositions, isLeftSide: Bool) -> Bool {
        let (wrist, elbow, shoulder) = isLeftSide ?
            (positions.leftWrist, positions.leftElbow, positions.leftShoulder) :
            (positions.rightWrist, positions.rightElbow, positions.rightShoulder)
        
        // 측면 펀치는 더 엄격한 조건 적용
        let punchExtension = abs(wrist.x - shoulder.x)
        let isPunchingForward = punchExtension > Constants.sidePunchExtensionThreshold
        
        let elbowAngle = calculateElbowAngle(shoulder, elbow, wrist)
        let isProperElbowAngle = elbowAngle > Constants.sidePunchElbowAngle
        
        return isPunchingForward && isProperElbowAngle
    }
    
    private func calculateElbowAngle(_ shoulder: CGPoint, _ elbow: CGPoint, _ wrist: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: shoulder.x - elbow.x, y: shoulder.y - elbow.y)
        let v2 = CGPoint(x: wrist.x - elbow.x, y: wrist.y - elbow.y)
        
        let dotProduct = v1.x * v2.x + v1.y * v2.y
        let magnitudes = sqrt(v1.x * v1.x + v1.y * v1.y) * sqrt(v2.x * v2.x + v2.y * v2.y)
        
        return acos(dotProduct / magnitudes) * 180 / .pi
    }
    
    private func extractValidPositions(from keypoints: [VNHumanBodyPoseObservation.JointName : VNRecognizedPoint]) -> PosePositions? {
        guard let leftWrist = keypoints[.leftWrist],
              let rightWrist = keypoints[.rightWrist],
              let leftShoulder = keypoints[.leftShoulder],
              let rightShoulder = keypoints[.rightShoulder],
              let leftElbow = keypoints[.leftElbow],
              let rightElbow = keypoints[.rightElbow],
              let nose = keypoints[.nose],
              let leftHip = keypoints[.leftHip],
              let rightHip = keypoints[.rightHip] else {
            return nil
        }
        
        let requiredPoints = [leftWrist, rightWrist, leftShoulder, rightShoulder,
                            leftElbow, rightElbow, nose, leftHip, rightHip]
        
        guard requiredPoints.allSatisfy({ $0.confidence > Constants.confidenceThreshold }) else {
            return nil
        }
        
        return PosePositions(
            leftWrist: leftWrist.location,
            rightWrist: rightWrist.location,
            leftShoulder: leftShoulder.location,
            rightShoulder: rightShoulder.location,
            leftElbow: leftElbow.location,
            rightElbow: rightElbow.location,
            nose: nose.location,
            leftHip: leftHip.location,
            rightHip: rightHip.location
        )
    }
}

// MARK: - Supporting Types
private struct PosePositions {
    let leftWrist, rightWrist: CGPoint
    let leftShoulder, rightShoulder: CGPoint
    let leftElbow, rightElbow: CGPoint
    let nose: CGPoint
    let leftHip, rightHip: CGPoint
    
    var shoulderCenter: CGPoint {
        CGPoint(
            x: (leftShoulder.x + rightShoulder.x) / 2,
            y: (leftShoulder.y + rightShoulder.y) / 2
        )
    }
    
    var hipCenter: CGPoint {
        CGPoint(
            x: (leftHip.x + rightHip.x) / 2,
            y: (leftHip.y + rightHip.y) / 2
        )
    }
} 
