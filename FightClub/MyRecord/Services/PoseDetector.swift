//
//  PoseDetector.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import Vision
import CoreGraphics

class PoseProcessor {
    private let poseDetector = PoseDetector()
    var onPunchDetected: (() -> Void)?
    var onUserDetectionChanged: ((Bool) -> Void)?
    
    func processFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let observations = request.results as? [VNHumanBodyPoseObservation],
                  let observation = observations.first else {
                self?.onUserDetectionChanged?(false)
                return
            }
            
            self?.onUserDetectionChanged?(true)
            if self?.poseDetector.detectPunchAction(from: observation) == true {
                self?.onPunchDetected?()
            }
        }
        
        try? handler.perform([request])
    }
}

class PoseDetector {
    private struct PosePositions {
        let leftWrist, rightWrist: CGPoint
        let leftShoulder, rightShoulder: CGPoint
        let leftElbow, rightElbow: CGPoint
        let nose: CGPoint
        let leftHip, rightHip: CGPoint
    }
    
    private enum StanceDirection {
        case front
        case left
        case right
    }
    
    func detectPunchAction(from observation: VNHumanBodyPoseObservation) -> Bool {
        // 키포인트 추출
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
        
        let stanceDirection = determineStanceDirection(
            leftShoulder: positions.leftShoulder,
            rightShoulder: positions.rightShoulder
        )
        
        switch stanceDirection {
        case .front:
            return detectFrontPunch(positions)
        case .left:
            return detectSidePunch(positions, isLeftSide: true)
        case .right:
            return detectSidePunch(positions, isLeftSide: false)
        }
    }
    
    private func isGuardPosition(_ positions: PosePositions) -> Bool {
        let handsAboveShoulders = positions.leftWrist.y < positions.leftShoulder.y &&
                                 positions.rightWrist.y < positions.rightShoulder.y
        
        let handsNearFace = abs(positions.leftWrist.x - positions.nose.x) < 0.25 &&
                           abs(positions.rightWrist.x - positions.nose.x) < 0.25
        
        let elbowsBent = calculateElbowAngle(positions.leftShoulder, positions.leftElbow, positions.leftWrist) < 120 &&
                        calculateElbowAngle(positions.rightShoulder, positions.rightElbow, positions.rightWrist) < 120
        
        return handsAboveShoulders && handsNearFace && elbowsBent
    }
    
    private func determineStanceDirection(leftShoulder: CGPoint, rightShoulder: CGPoint) -> StanceDirection {
        let shoulderDiff = abs(leftShoulder.x - rightShoulder.x)
        
        if shoulderDiff > 0.15 {
            return .front
        } else {
            return leftShoulder.x > rightShoulder.x ? .left : .right
        }
    }
    
    private func detectFrontPunch(_ positions: PosePositions) -> Bool {
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
        
        return leftPunch || rightPunch
    }
    
    private func detectSidePunch(_ positions: PosePositions, isLeftSide: Bool) -> Bool {
        let (wrist, elbow, shoulder) = isLeftSide ?
            (positions.leftWrist, positions.leftElbow, positions.leftShoulder) :
            (positions.rightWrist, positions.rightElbow, positions.rightShoulder)
        
        return checkPunchConditions(
            wrist: wrist,
            elbow: elbow,
            shoulder: shoulder,
            nose: positions.nose
        )
    }
    
    private func checkPunchConditions(wrist: CGPoint, elbow: CGPoint, shoulder: CGPoint, nose: CGPoint) -> Bool {
        // 1. 손 뻗기 거리
        let extensionDistance = abs(wrist.x - shoulder.x)
        let isProperExtension = extensionDistance > 0.2
        
        // 2. 팔꿈치 각도
        let elbowAngle = calculateElbowAngle(shoulder, elbow, wrist)
        let isProperElbowAngle = elbowAngle > 90 && elbowAngle < 170
        
        // 3. 손목 높이
        let isProperHeight = wrist.y >= shoulder.y - 0.3 &&
                           wrist.y <= nose.y + 0.3
        
        return isProperExtension && isProperElbowAngle && isProperHeight
    }
    
    private func calculateElbowAngle(_ shoulder: CGPoint, _ elbow: CGPoint, _ wrist: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: shoulder.x - elbow.x, y: shoulder.y - elbow.y)
        let v2 = CGPoint(x: wrist.x - elbow.x, y: wrist.y - elbow.y)
        
        let dotProduct = v1.x * v2.x + v1.y * v2.y
        let magnitudes = sqrt(v1.x * v1.x + v1.y * v1.y) * sqrt(v2.x * v2.x + v2.y * v2.y)
        
        let angle = acos(dotProduct / magnitudes) * 180 / .pi
        return angle
    }
}
