//
//  RecordListView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI
import CoreData
import AVFoundation
import Vision
import Combine

struct RecordListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BoxingSession.date, ascending: false)],
        animation: .default)
    private var sessions: FetchedResults<BoxingSession>
    
    @StateObject private var recordingManager = RecordingManager()
    @State private var showingRecordingView = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionRowView(session: session)
                    }
                }
                .onDelete(perform: deleteSessions)
            }
            .navigationTitle("복싱 기록")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingRecordingView = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingRecordingView) {
                RecordingView(recordingManager: recordingManager)
            }
        }
    }
    
    private func deleteSessions(offsets: IndexSet) {
        withAnimation {
            offsets.map { sessions[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting session: \(error)")
            }
        }
    }
}

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
    
    // MARK: - Camera Permission
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isCameraAuthorized = true
            self.setupCaptureSession()
            self.setupVideoProcessing()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isCameraAuthorized = granted
                    if granted {
                        self?.setupCaptureSession()
                        self?.setupVideoProcessing()
                    }
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
        // 메인 스레드에서 설정
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let session = AVCaptureSession()
            self.captureSession = session
            
            // 세션 구성 시작
            session.beginConfiguration()
            session.sessionPreset = .high
            
            // 카메라 설정
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                print("Failed to get front camera")
                return
            }
            
            do {
                // 카메라 구성
                try camera.lockForConfiguration()
                if camera.isFocusModeSupported(.continuousAutoFocus) {
                    camera.focusMode = .continuousAutoFocus
                }
                if camera.isExposureModeSupported(.continuousAutoExposure) {
                    camera.exposureMode = .continuousAutoExposure
                }
                camera.unlockForConfiguration()
                
                // 입력 설정
                let input = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(input) {
                    session.addInput(input)
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
                }
                self.videoOutput = videoOutput
                
                // 동영상 녹화 출력 설정
                let movieOutput = AVCaptureMovieFileOutput()
                if session.canAddOutput(movieOutput) {
                    session.addOutput(movieOutput)
                }
                self.movieOutput = movieOutput
                
                // 프리뷰 레이어 설정
                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.connection?.videoOrientation = .portrait
                self.previewLayer = previewLayer
                
                // 세션 구성 완료
                session.commitConfiguration()
                
                // 세션 시작 (백그라운드 스레드에서)
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                }
                
            } catch {
                print("Failed to setup camera: \(error)")
                return
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
    
    // MARK: - Public Methods
    func startRecording() {
        guard let captureSession = captureSession else { return }
        
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
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
    
    func stopRecording() {
        guard let captureSession = captureSession else { return }
        
        movieOutput?.stopRecording()
        
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.stopRunning()
            }
        }
        
        isRecording = false
        timer?.invalidate()
        timer = nil
    }
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return previewLayer
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension RecordingManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 프레임 퍼블리셔에 전달
        framePublisher.send(sampleBuffer)
        
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

struct SessionRowView: View {
    let session: BoxingSession
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(session.date, style: .date)
                .font(.headline)
            HStack {
                Label("\(session.punchCount) 펀치", systemImage: "hand.raised.fill")
                Spacer()
                Text(String(format: "%.1f분", session.duration / 60))
                    .foregroundColor(.secondary)
            }
            if let memo = session.memo {
                Text(memo)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
