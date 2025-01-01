import Foundation
import AVFoundation
import Vision
import Combine
import UIKit

// MARK: - Recording Manager
class RecordingManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var punchCount = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var previewImage: UIImage?
    @Published var isCameraAuthorized = false
    
    // MARK: - Video Processing
    private var videoProcessingChain: VideoProcessingChain?
    private let punchDetector = PunchDetector()
    private var framePublisher = PassthroughSubject<CMSampleBuffer, Never>()
    
    // MARK: - Recording Properties
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Timer
    private var timer: Timer?
    private var startTime: Date?
    
    override init() {
        super.init()
        checkCameraPermission()
    }
    
    deinit {
        stopCamera()
    }
    
    // MARK: - Camera Control
    func startCamera() {
        guard isCameraAuthorized else { 
            print("Camera not authorized")
            return 
        }
        
        if captureSession == nil {
            print("Setting up new capture session")
            setupCaptureSession()
            setupVideoProcessing()
        }
        
        guard let session = captureSession else {
            print("Capture session is nil")
            return
        }
        
        // 백그라운드 스레드에서 세션 시작
        DispatchQueue.global(qos: .userInitiated).async {
            if !session.isRunning {
                session.startRunning()
                print("Camera session started running")
            }
        }
    }
    
    func stopCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let session = self.captureSession else { return }
            if session.isRunning {
                session.stopRunning()
                print("Camera session stopped")
            }
        }
    }
    
    // MARK: - Camera Permission
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isCameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isCameraAuthorized = granted
                }
            }
        case .denied, .restricted:
            self.isCameraAuthorized = false
        @unknown default:
            self.isCameraAuthorized = false
        }
    }
    
    // MARK: - Setup Methods
    private func setupCaptureSession() {
        print("Setting up capture session...")
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        // 카메라 설정
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("Failed to get front camera")
            return
        }
        
        do {
            session.beginConfiguration()
            
            // 입력 설정
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                print("Camera input added successfully")
            } else {
                print("Could not add camera input")
                return
            }
            
            // 비디오 출력 설정
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
            videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                if let connection = videoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                    connection.isVideoMirrored = true
                }
                print("Video output added successfully")
            }
            self.videoOutput = videoOutput
            
            // 동영상 녹화 출력 설정
            let movieOutput = AVCaptureMovieFileOutput()
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
                print("Movie output added successfully")
            }
            self.movieOutput = movieOutput
            
            session.commitConfiguration()
            self.captureSession = session
            
            // 프리뷰 레이어 설정
            DispatchQueue.main.async { [weak self] in
                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.connection?.videoOrientation = .portrait
                self?.previewLayer = previewLayer
                print("Preview layer configured")
            }
            
            print("Capture session setup completed")
            
        } catch {
            print("Failed to setup camera: \(error)")
            return
        }
    }
    
    private func setupVideoProcessing() {
        print("Setting up video processing...")
        videoProcessingChain = VideoProcessingChain()
        videoProcessingChain?.delegate = self
        
        // 프레임 퍼블리셔 설정
        let genericPublisher = framePublisher
            .map { buffer -> Frame in
                return buffer
            }
            .eraseToAnyPublisher()
        
        videoProcessingChain?.upstreamFramePublisher = genericPublisher
        print("Video processing setup completed")
    }
    
    // MARK: - Public Methods
    func startRecording() {
        guard let captureSession = captureSession else { return }
        
        if !captureSession.isRunning {
            startCamera()
        }
        
        isRecording = true
        startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(startTime)
        }
        
        // 동영상 파일 저장 경로
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoPath = documentsPath.appendingPathComponent("boxing_session_\(Date().timeIntervalSince1970).mov")
        movieOutput?.startRecording(to: videoPath, recordingDelegate: self)
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard let movieOutput = movieOutput else {
            completion(nil)
            return
        }
        
        // 현재 녹화 중인 파일의 URL을 저장
        let currentRecordingURL = movieOutput.outputFileURL
        
        movieOutput.stopRecording()
        stopCamera()
        
        isRecording = false
        timer?.invalidate()
        timer = nil
        
        completion(currentRecordingURL)
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        print("Getting preview layer: \(previewLayer != nil)")
        return previewLayer
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension RecordingManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 프레임 퍼블리셔에 전달
        framePublisher.send(sampleBuffer)
        
        // 프치 감지
        if isRecording {
            punchDetector.detectPunch(in: sampleBuffer) { [weak self] isPunch in
                if isPunch {
                    DispatchQueue.main.async {
                        self?.punchCount += 1
                        print("Punch detected! Count: \(self?.punchCount ?? 0)")
                    }
                }
            }
        }
        
        // 프리뷰 이미지 업데이트
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let context = CIContext()
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                DispatchQueue.main.async {
                    self.previewImage = UIImage(cgImage: cgImage)
                }
            }
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension RecordingManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
            return
        }
        
        print("Recording finished: \(outputFileURL)")
    }
}

// MARK: - VideoProcessingChainDelegate
extension RecordingManager: VideoProcessingChainDelegate {
    func videoProcessingChain(_ chain: VideoProcessingChain, didPredict actionPrediction: ActionPrediction, for frames: Int) {
        // 액션 예측 처리
    }
    
    func videoProcessingChain(_ chain: VideoProcessingChain, didDetectAction action: String) {
        // 펀치 동작 감지 시 처리
        DispatchQueue.main.async {
            self.punchCount += 1
        }
    }
    
    func videoProcessingChain(_ chain: VideoProcessingChain, didDetect poses: [Pose]?, in frame: CGImage) {
        // 포즈 감지 결과 처리
    }
} 