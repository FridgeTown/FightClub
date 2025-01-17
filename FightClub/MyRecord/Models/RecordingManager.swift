import Foundation
import AVFoundation
import Vision
import Combine
import UIKit

// MARK: - Notification Names
extension Notification.Name {
    static let punchDetected = Notification.Name("punchDetected")
}

// MARK: - Recording Manager
class RecordingManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isCameraAuthorized = false
    @Published var isRecording = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var punchCount = 0
    
    // MARK: - Video Processing
    private var videoProcessingChain: VideoProcessingChain?
    private let punchDetector = PunchDetector()
    private var framePublisher = PassthroughSubject<CMSampleBuffer, Never>()
    
    // MARK: - Recording Properties
    private var captureSession: AVCaptureSession?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var timer: Timer?
    private var startTime: Date?
    
    override init() {
        super.init()
        checkCameraAuthorization()
    }
    
    deinit {
        print("RecordingManager deinit")
        stopCamera()
        stopRecording(completion: nil)
    }
    
    func startCamera() {
        guard isCameraAuthorized else { return }
        
        let session = AVCaptureSession()
        self.captureSession = session
        
        // 카메라 설정
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            return
        }
        
        guard session.canAddInput(videoInput) else { return }
        session.addInput(videoInput)
        
        // 비디오 데이터 출력 설정 (펀치 감지용)
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
                connection.isVideoMirrored = true
            }
        }
        self.videoDataOutput = videoDataOutput
        
        // 비디오 녹화 출력 설정
        let videoOutput = AVCaptureMovieFileOutput()
        self.videoOutput = videoOutput
        
        guard session.canAddOutput(videoOutput) else { return }
        session.addOutput(videoOutput)
        
        // 프리뷰 레이어 설정
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        self.previewLayer = previewLayer
        
        // 비디오 처리 체인 설정
        setupVideoProcessing()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopCamera() {
        // 현재 세션 참조 저장
        let currentSession = captureSession
        
        // 먼저 참조 제거
        self.previewLayer = nil
        self.videoOutput = nil
        self.videoDataOutput = nil
        self.videoProcessingChain = nil
        self.captureSession = nil
        
        // 백그라운드 큐에서 세션 중지
        if let session = currentSession {
            DispatchQueue.global(qos: .userInitiated).async {
                if session.isRunning {
                    session.stopRunning()
                }
            }
        }
    }
    
    private func setupVideoProcessing() {
        videoProcessingChain = VideoProcessingChain()
        videoProcessingChain?.delegate = self
        
        // 프레임 퍼블리셔 설정
        let genericPublisher = framePublisher
            .map { buffer -> Frame in
                return buffer
            }
            .eraseToAnyPublisher()
        
        videoProcessingChain?.upstreamFramePublisher = genericPublisher
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return previewLayer
    }
    
    func startRecording() {
        guard let output = videoOutput, !isRecording else { return }
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let tempFileName = "temp_recording_\(Date().timeIntervalSince1970).mov"
        let fileURL = documentsPath.appendingPathComponent(tempFileName)
        
        output.startRecording(to: fileURL, recordingDelegate: self)
        isRecording = true
        startTime = Date()
        
        // 타이머 시작
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            self.elapsedTime = -startTime.timeIntervalSinceNow
        }
    }
    
    func stopRecording(completion: ((URL?) -> Void)?) {
        guard isRecording, let output = videoOutput else {
            completion?(nil)
            return
        }
        
        output.stopRecording()
        isRecording = false
        startTime = nil
        
        // 타이머 정지
        timer?.invalidate()
        timer = nil
        
        // 완료 콜백은 fileOutput(_:didFinishRecordingTo:from:error:)에서 호출됨
        self.recordingCompletionHandler = completion
    }
    
    private func checkCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isCameraAuthorized = granted
                }
            }
        default:
            isCameraAuthorized = false
        }
    }
    
    private var recordingCompletionHandler: ((URL?) -> Void)?
    
    func cleanup() {
        // 타이머 정리
        timer?.invalidate()
        timer = nil
        
        // 비디오 처리 체인 정리
        videoProcessingChain = nil
        
        // 프레임 퍼블리셔 초기화
        framePublisher = PassthroughSubject<CMSampleBuffer, Never>()
        
        // 녹화 관련 변수 초기화
        isRecording = false
        elapsedTime = 0
        punchCount = 0
        startTime = nil
        
        // 카메라 세션 정리
        stopCamera()
    }
    
    private func handlePunchDetection() {
        DispatchQueue.main.async {
            self.punchCount += 1
            
            // 펀치 감지 알림 발송
            NotificationCenter.default.post(
                name: .punchDetected,
                object: nil,
                userInfo: ["punchCount": self.punchCount]
            )
        }
    }

}

extension RecordingManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if error != nil {
                self?.recordingCompletionHandler?(nil)
            } else {
                self?.recordingCompletionHandler?(outputFileURL)
            }
            self?.recordingCompletionHandler = nil
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension RecordingManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 프레임 퍼블리셔에 전달
        framePublisher.send(sampleBuffer)
        
        // 펀치 감지
        if isRecording {
            punchDetector.detectPunch(in: sampleBuffer) { [weak self] isPunch in
                if isPunch {
                    self?.handlePunchDetection()
                }
            }
        }
    }
}

// MARK: - VideoProcessingChainDelegate
extension RecordingManager: VideoProcessingChainDelegate {
    func videoProcessingChain(_ chain: VideoProcessingChain, didPredict actionPrediction: ActionPrediction, for frames: Int) {
        // 액션 예측 처리
    }
    
    func videoProcessingChain(_ chain: VideoProcessingChain, didDetectAction action: String) {
        // 펀치 동작 감지 시 처리
        handlePunchDetection()
    }
    
    func videoProcessingChain(_ chain: VideoProcessingChain, didDetect poses: [Pose]?, in frame: CGImage) {
        // 포즈 감지 결과 처리
    }
} 
