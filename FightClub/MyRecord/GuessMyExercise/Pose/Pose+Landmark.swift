/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A `Landmark` is the name and location of a point on a human body, including:
 - Left shoulder
 - Right eye
 - Nose
*/

import UIKit
import Vision

extension Pose {
    typealias JointName = VNHumanBodyPoseObservation.JointName

    /// The name and location of a point of interest on a human body.
    ///
    /// Each landmark defines its location in an image and the name of the body
    /// joint it represents, such as nose, left eye, right knee, and so on.
    struct Landmark {
        /// The minimum `VNRecognizedPoint` confidence for a valid `Landmark`.
        private static let threshold: Float = 0.2

        /// The drawing radius of a landmark.
        private static let radius: CGFloat = 14.0

        /// The name of the landmark.
        ///
        /// For example, "left shoulder", "right knee", "nose", and so on.
        let name: JointName

        /// The location of the landmark in normalized coordinates.
        ///
        /// When calling `drawToContext()`, use a transform to apply a scale
        /// that's appropriate for the graphics context.
        let location: CGPoint

        /// Creates a landmark from a point.
        /// - Parameter point: A point in a human body pose observation.
        init?(_ point: VNRecognizedPoint) {
            // Only create a landmark from a point that satisfies the minimum
            // confidence.
            guard point.confidence >= Pose.Landmark.threshold else {
                return nil
            }

            name = JointName(rawValue: point.identifier)
            location = point.location
        }

        /// Draws a circle at the landmark's location after transformation.
        /// - Parameters:
        ///   - context: A context the method uses to draw the landmark.
        ///   - transform: A transform that modifies the point locations.
        func drawToContext(_ context: CGContext,
                           applying transform: CGAffineTransform? = nil,
                           at scale: CGFloat = 1.0) {

            context.setFillColor(UIColor.white.cgColor)
            context.setStrokeColor(UIColor.darkGray.cgColor)

            // Define the rectangle's origin by applying the transform to the
            // landmark's normalized location.
            let origin = location.applying(transform ?? .identity)

            // Define the size of the circle's rectangle with the radius.
            let radius = Landmark.radius * scale
            let diameter = radius * 2
            let rectangle = CGRect(x: origin.x - radius,
                                   y: origin.y - radius,
                                   width: diameter,
                                   height: diameter)

            context.addEllipse(in: rectangle)
            context.drawPath(using: CGPathDrawingMode.fillStroke)
        }
    }

    /// 현재 사용자의 자세 방향을 판단하는 함수
    private func determineStanceDirection(leftShoulder: CGPoint, rightShoulder: CGPoint) -> StanceDirection {
        let shoulderDiff = abs(leftShoulder.x - rightShoulder.x)
        
        if shoulderDiff > 0.15 {  // 어깨가 충분히 벌어져 있으면 정면
            return .front
        } else {  // 어깨가 겹쳐 보이면 측면
            // 왼쪽 어깨가 오른쪽 어깨보다 앞에 있으면 왼쪽 방향
            return leftShoulder.x > rightShoulder.x ? .left : .right
        }
    }

    /// 자세 방향을 나타내는 열거형
    private enum StanceDirection {
        case front  // 정면
        case left   // 왼쪽 방향
        case right  // 오른쪽 방향
    }

    /// 펀치 동작을 감지하는 함수
    func detectPunchAction(from observation: VNHumanBodyPoseObservation) -> Bool {
        // 모든 키포인트 가져오기
        guard let keypoints = try? observation.recognizedPoints(.all) else { return false }
        
        // 필요한 키포인트들 추출
        guard let leftWrist = keypoints[.leftWrist],
              let rightWrist = keypoints[.rightWrist],
              let leftShoulder = keypoints[.leftShoulder],
              let rightShoulder = keypoints[.rightShoulder],
              let leftElbow = keypoints[.leftElbow],
              let rightElbow = keypoints[.rightElbow],
              let nose = keypoints[.nose],
              let leftHip = keypoints[.leftHip],
              let rightHip = keypoints[.rightHip] else {
            return false
        }
        
        // 신뢰도 체크
        let confidenceThreshold: Float = 0.2
        guard leftWrist.confidence > confidenceThreshold &&
              rightWrist.confidence > confidenceThreshold &&
              leftShoulder.confidence > confidenceThreshold &&
              rightShoulder.confidence > confidenceThreshold &&
              leftElbow.confidence > confidenceThreshold &&
              rightElbow.confidence > confidenceThreshold &&
              nose.confidence > confidenceThreshold &&
              leftHip.confidence > confidenceThreshold &&
              rightHip.confidence > confidenceThreshold else {
            return false
        }
        
        let positions = PosePositions(
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
        
        // 가드 자세인 경우 펀치로 인식하지 않음
        if isGuardPosition(positions) {
            return false
        }
        
        // 상체 회전 각도 계산
        let torsoAngle = calculateTorsoAngle(positions)
        let stanceDirection = determineStanceDirection(leftShoulder: positions.leftShoulder, rightShoulder: positions.rightShoulder)
        
        // 방향에 따른 펀치 감지
        switch stanceDirection {
        case .front:
            return detectFrontPunch(positions)
        case .left:
            return detectSidePunch(positions, isLeftSide: true)
        case .right:
            return detectSidePunch(positions, isLeftSide: false)
        }
    }
    
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
    
    // 상체 회전 각도 계산
    private func calculateTorsoAngle(_ positions: PosePositions) -> CGFloat {
        let shoulderVector = CGPoint(
            x: positions.rightShoulder.x - positions.leftShoulder.x,
            y: positions.rightShoulder.y - positions.leftShoulder.y
        )
        
        // 어깨 벡터와 수평선 사이의 각도 계산
        let angle = atan2(shoulderVector.y, shoulderVector.x) * 180 / .pi
        return angle
    }
    
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
    
    private func calculateElbowAngle(_ shoulder: CGPoint, _ elbow: CGPoint, _ wrist: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: shoulder.x - elbow.x, y: shoulder.y - elbow.y)
        let v2 = CGPoint(x: wrist.x - elbow.x, y: wrist.y - elbow.y)
        
        let dotProduct = v1.x * v2.x + v1.y * v2.y
        let magnitudes = sqrt(v1.x * v1.x + v1.y * v1.y) * sqrt(v2.x * v2.x + v2.y * v2.y)
        
        let angle = acos(dotProduct / magnitudes) * 180 / .pi
        return angle
    }
    
    private func detectFrontPunch(_ positions: PosePositions) -> Bool {
        // 왼손 잽
        let leftJab = checkJabConditions(
            wrist: positions.leftWrist,
            elbow: positions.leftElbow,
            shoulder: positions.leftShoulder,
            nose: positions.nose,
            otherWrist: positions.rightWrist
        )
        
        // 오른손 잽
        let rightJab = checkJabConditions(
            wrist: positions.rightWrist,
            elbow: positions.rightElbow,
            shoulder: positions.rightShoulder,
            nose: positions.nose,
            otherWrist: positions.leftWrist
        )
        
        // 일반 펀치
        let leftPunch = checkPunchConditions(
            wrist: positions.leftWrist,
            elbow: positions.leftElbow,
            shoulder: positions.leftShoulder,
            nose: positions.nose
        )
        
        let rightPunch = checkPunchConditions(
            wrist: positions.rightWrist,
            elbow: positions.rightElbow,
            shoulder: positions.rightShoulder,
            nose: positions.nose
        )
        
        return leftJab || rightJab || leftPunch || rightPunch
    }
    
    private func detectSidePunch(_ positions: PosePositions, isLeftSide: Bool) -> Bool {
        let (frontWrist, frontElbow, frontShoulder) = isLeftSide ?
            (positions.leftWrist, positions.leftElbow, positions.leftShoulder) :
            (positions.rightWrist, positions.rightElbow, positions.rightShoulder)
            
        let (backWrist, backElbow, backShoulder) = isLeftSide ?
            (positions.rightWrist, positions.rightElbow, positions.rightShoulder) :
            (positions.leftWrist, positions.leftElbow, positions.leftShoulder)
        
        // 앞손 잽
        let frontJab = checkSideJabConditions(
            wrist: frontWrist,
            elbow: frontElbow,
            shoulder: frontShoulder,
            nose: positions.nose
        )
        
        // 뒷손 잽
        let backJab = checkSideJabConditions(
            wrist: backWrist,
            elbow: backElbow,
            shoulder: backShoulder,
            nose: positions.nose
        )
        
        // 일반 펀치
        let frontPunch = checkSidePunchConditions(
            wrist: frontWrist,
            elbow: frontElbow,
            shoulder: frontShoulder,
            nose: positions.nose
        )
        
        let backPunch = checkSidePunchConditions(
            wrist: backWrist,
            elbow: backElbow,
            shoulder: backShoulder,
            nose: positions.nose
        )
        
        return frontJab || backJab || frontPunch || backPunch
    }
    
    private func checkSideJabConditions(
        wrist: CGPoint,
        elbow: CGPoint,
        shoulder: CGPoint,
        nose: CGPoint
    ) -> Bool {
        // 1. 손 뻗기 거리
        let extensionDistance = abs(wrist.x - shoulder.x)
        let isProperExtension = extensionDistance > 0.3  // 측면에서는 더 긴 거리 필요
        
        // 2. 팔꿈치 각도 (거의 편 상태)
        let elbowAngle = calculateElbowAngle(shoulder, elbow, wrist)
        let isProperElbowAngle = elbowAngle > 160
        
        // 3. 손목 높이 (얼굴 높이 근처)
        let isProperHeight = abs(wrist.y - nose.y) < 0.25
        
        // 4. 빠른 동작
        let isQuickExtension = extensionDistance > 0.25
        
        return isProperExtension && isProperElbowAngle && isProperHeight && isQuickExtension
    }
    
    private func checkSidePunchConditions(
        wrist: CGPoint,
        elbow: CGPoint,
        shoulder: CGPoint,
        nose: CGPoint
    ) -> Bool {
        // 1. 손 뻗기 거리
        let extensionDistance = abs(wrist.x - shoulder.x)
        let isProperExtension = extensionDistance > 0.25
        
        // 2. 팔꿈치 각도 (약간 구부러진 상태 허용)
        let elbowAngle = calculateElbowAngle(shoulder, elbow, wrist)
        let isProperElbowAngle = elbowAngle > 100 && elbowAngle < 170
        
        // 3. 손목 높이 (더 넓은 범위 허용)
        let isProperHeight = wrist.y >= shoulder.y - 0.3 &&
                           wrist.y <= nose.y + 0.3
        
        return isProperExtension && isProperElbowAngle && isProperHeight
    }

    private func checkJabConditions(
        wrist: CGPoint,
        elbow: CGPoint,
        shoulder: CGPoint,
        nose: CGPoint,
        otherWrist: CGPoint
    ) -> Bool {
        // 1. 손 뻗기 거리
        let extensionDistance = abs(wrist.x - shoulder.x)
        let isProperExtension = extensionDistance > 0.25
        
        // 2. 팔꿈치 각도 (거의 편 상태)
        let elbowAngle = calculateElbowAngle(shoulder, elbow, wrist)
        let isProperElbowAngle = elbowAngle > 150
        
        // 3. 손목 높이 (얼굴 높이)
        let isProperHeight = abs(wrist.y - nose.y) < 0.2
        
        // 4. 반대쪽 손 위치 (가드 위치)
        let isGuardHandProper = abs(otherWrist.y - nose.y) < 0.25
        
        // 5. 빠른 동작
        let isQuickExtension = extensionDistance > 0.2
        
        return isProperExtension &&
               isProperElbowAngle &&
               isProperHeight &&
               isGuardHandProper &&
               isQuickExtension
    }
    
    private func checkPunchConditions(
        wrist: CGPoint,
        elbow: CGPoint,
        shoulder: CGPoint,
        nose: CGPoint
    ) -> Bool {
        // 1. 손 뻗기 거리
        let extensionDistance = abs(wrist.x - shoulder.x)
        let isProperExtension = extensionDistance > 0.2
        
        // 2. 팔꿈치 각도 (약간 구부러진 상태 허용)
        let elbowAngle = calculateElbowAngle(shoulder, elbow, wrist)
        let isProperElbowAngle = elbowAngle > 90 && elbowAngle < 170
        
        // 3. 손목 높이 (더 넓은 범위 허용)
        let isProperHeight = wrist.y >= shoulder.y - 0.3 &&
                           wrist.y <= nose.y + 0.3
        
        return isProperExtension && isProperElbowAngle && isProperHeight
    }
}
