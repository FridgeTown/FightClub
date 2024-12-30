//
//  VideoRecorder.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import AVFoundation
import Combine
import CoreMedia
import Vision

class VideoRecorder: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var poseProcessor: PoseProcessor?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    @Published var videoURL: URL?
    @Published var highlights: [TimeInterval] = []
    @Published var userDetected: Bool = false
    @Published var punchCount: Int = 0
    @Published var isAuthorized = false
    private var tempVideoURL: URL?
    
    private var lastPunchTime: Date = .distantPast
    private let punchCooldown: TimeInterval = 0.5
    
    override init() {
        super.init()
        
        poseProcessor = PoseProcessor()
        poseProcessor?.onPunchDetected = { [weak self] in
            self?.handlePunchDetection()
        }
        poseProcessor?.onUserDetectionChanged = { [weak self] detected in
            DispatchQueue.main.async {
                self?.userDetected = detected
            }
        }
    }
    
    private func handlePunchDetection() {
        let currentTime = Date()
        guard currentTime.timeIntervalSince(lastPunchTime) >= punchCooldown else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 펀치 카운트 증가
            self.punchCount += 1
            
            // 현재 녹화 시간을 하이라이트로 저장
            if let currentVideoTime = self.videoOutput?.recordedDuration.seconds {
                // 하이라이트 시작 시간 (펀치 동작 1초 전부터)
                let highlightStart = max(0, currentVideoTime - 1.0)
                self.highlights.append(highlightStart)
                
                // 중복된 하이라이트 제거 (1초 이내의 간격)
                self.highlights = self.highlights.enumerated().filter { index, timestamp in
                    if index == 0 { return true }
                    let previousTimestamp = self.highlights[index - 1]
                    return timestamp - previousTimestamp > 1.0
                }.map { $0.1 }
            }
        }
        lastPunchTime = currentTime
    }
    
    // 하이라이트 구간 가져오기 (시작 시간과 지속 시간)
    func getHighlightSegments() -> [(start: TimeInterval, duration: TimeInterval)] {
        return highlights.map { startTime in
            // 각 하이라이트는 시작 시간부터 3초 동안 지속
            (start: startTime, duration: 3.0)
        }
    }
    
    func startSession() {
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        // 기존 세션이 실행 중이면 중지
        if session.isRunning {
            session.stopRunning()
        }
        
        session.beginConfiguration()
        
        // 기존 입력과 출력 제거
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        // 비디오 입력 설정
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            print("카메라 설정 실패")
            return
        }
        
        guard session.canAddInput(videoInput) else {
            print("비디오 입력 추가 실패")
            return
        }
        session.addInput(videoInput)
        
        // 비디오 출력 설정
        let videoOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            self.videoOutput = videoOutput
        }
        
        // Vision 처리를 위한 출력 설정
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.boxingtracker.videoprocessing"))
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        
        session.commitConfiguration()
        
        // 메인 스레드에서 세션 시작
        DispatchQueue.main.async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                }
            }
        default:
            self.isAuthorized = false
        }
    }
    
    func stopSession() {
        session.stopRunning()
    }
    
    func startRecording() {
        // 임시 파일 URL 생성
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoName = "boxing_session_\(Date().timeIntervalSince1970).mov"
        tempVideoURL = documentsPath.appendingPathComponent(videoName)
        
        guard let fileURL = tempVideoURL else { return }
        
        // 이전 파일 삭제
        try? FileManager.default.removeItem(at: fileURL)
        
        // 녹화 시작
        videoOutput?.startRecording(to: fileURL, recordingDelegate: self)
    }
    
    func stopRecording() {
        videoOutput?.stopRecording()
    }
}

extension VideoRecorder: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        poseProcessor?.processFrame(imageBuffer, timestamp: timestamp)
    }
}

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error == nil {
            // 녹화 완료 후 URL 업데이트
            DispatchQueue.main.async { [weak self] in
                self?.videoURL = outputFileURL
            }
        } else {
            print("Recording error: \(String(describing: error))")
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // 녹화 시작 시 초기화
        highlights.removeAll()
        punchCount = 0
    }
}
