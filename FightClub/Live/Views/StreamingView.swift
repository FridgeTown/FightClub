//
//  StreamingView.swift
//  FightClub
//
//  Created by Edward Lee on 1/6/25.
//

import SwiftUI
import AVFoundation
import LiveKit
import KeychainAccess
import Network

// 카메라 리 클래스
class StreamingManager: ObservableObject {
    static let shared = StreamingManager()
    
    let captureSession = AVCaptureSession()
    let previewLayer: AVCaptureVideoPreviewLayer
    
    @Published var isStreaming = false
    private var currentVideoTrack: LocalVideoTrack?
    
    private init() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer.videoGravity = .resizeAspectFill
        setupCaptureSession()
        startPreviewSession()
    }
    
    private func setupCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        // 후면 카메라 설정
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("후면 카메라를 찾을 수 없습니다")
            return
        }
        
        do {
            // 기존 입력/출력 제거
            captureSession.inputs.forEach { captureSession.removeInput($0) }
            captureSession.outputs.forEach { captureSession.removeOutput($0) }
            
            // 입력 설정
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            // 출력 설정
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }
            
            // 비디오 방향 설정
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .landscapeRight
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = false
                }
            }
        } catch {
            print("카메라 설정 오류: \(error)")
        }
        
        captureSession.commitConfiguration()
    }
    
    // 프리뷰 카메라 시작
    func startPreviewSession() {
        guard !captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    // 프리뷰 카메라 정지
    func stopPreviewSession() {
        guard captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    func getCaptureSession() -> AVCaptureSession {
        return captureSession
    }
}

// LiveKit VideoView를 위한 SwiftUI 퍼
struct LiveKitVideoView: UIViewRepresentable {
    let publication: TrackPublication
    
    func makeUIView(context: Context) -> VideoView {
        let videoView = VideoView()
        videoView.track = publication.track as! any VideoTrack
        return videoView
    }
    
    func updateUIView(_ uiView: VideoView, context: Context) {
        uiView.track = publication.track as! any VideoTrack
    }
}

struct StreamingView: View {
    @StateObject private var viewModel: StreamingViewModel
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var appCtx: AppContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var streamingManager = StreamingManager.shared
    let channelId: String
    
    @State private var isRoundActive = false
    @State private var remainingTime: TimeInterval = 180
    @State private var timer: Timer?
    @State private var messages: [ChatMessage] = []
    @State private var newMessage = ""
    
    // 다이얼로그 상태
    @State private var showStartStreamingAlert = false
    @State private var showStopStreamingAlert = false
    @State private var isLoading = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var httpService = HTTPClient()
    private let mainRed = Color("mainRed")
    
    init(viewModel: StreamingViewModel = DIContainer.shared.makeStreamViewModel(),
         channelId: String) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.channelId = channelId
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 카메라 프리뷰 (스트리밍 시작 전)
                if !streamingManager.isStreaming {
                    CameraPreview()
                        .ignoresSafeArea()
                }
                
                // LiveKit 비디오 트랙 (스트리밍 중)
                if streamingManager.isStreaming,
                   let publication = roomCtx.room.localParticipant.videoTracks.first {
                    LiveKitVideoView(publication: publication)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                }
                
                // 상단 오버레이
                VStack {
                    HStack {
                        // 뒤로가기 버튼
                        Button(action: {
                            if streamingManager.isStreaming {
                                showStopStreamingAlert = true
                            } else {
                                setupPortraitOrientation()  // 세로 모드로 전환
                                dismiss()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                    }
                    
                    if isRoundActive {
                        Text(timeString(from: remainingTime))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.black.opacity(0.6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(mainRed, lineWidth: 2)
                                    )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 10)
                    }
                    Spacer()
                }
                .padding(.top, 40)
                
                // 채팅 오버레이
                HStack {
                    Spacer()
                    chatOverlay
                        .frame(width: geometry.size.width * 0.3)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.trailing, 20)
                }
                
                // 컨트롤 버튼들
                VStack {
                    Spacer()
                    HStack(spacing: 30) {
                        ControlButton(
                            text: isRoundActive ? "라운드 정지" : "라운드 시작",
                            action: {
                                if isRoundActive {
                                    stopRound()
                                } else {
                                    startRound()
                                }
                            }
                        )
                        
                        ControlButton(
                            text: streamingManager.isStreaming ? "실시간 방송 정지" : "실시간 방송 시작",
                            action: {
                                if streamingManager.isStreaming {
                                    showStopStreamingAlert = true
                                } else {
                                    showStartStreamingAlert = true
                                }
                            }
                        )
                    }
                    .padding(.bottom, 40)
                }
                
                // 로딩 인디케이터
                if isLoading {
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                    ProgressView("방송 연결 중...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                }
            }
        }
        .alert("실시간 방송 시작", isPresented: $showStartStreamingAlert) {
            Button("취소", role: .cancel) { }
            Button("시작") {
                startLiveStreaming()
            }
        } message: {
            Text("실시간 방송을 시작하시겠습니까?")
        }
        .alert("실시간 방송 종료", isPresented: $showStopStreamingAlert) {
            Button("취소", role: .cancel) { }
            Button("종료", role: .destructive) {
                Task {
                    if await stopLiveStreaming() {
                        setupPortraitOrientation()
                        await MainActor.run {
                            dismiss()
                        }
                    }
                }
            }
        } message: {
            Text("실시간 방송을 종료하시겠습니까?")
        }
        .alert("라이브 스트리밍 오류", isPresented: $showErrorAlert) {
            Button("확인") {
                dismiss()
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            StreamingManager.shared.startPreviewSession()
            setupLandscapeOrientation()
        }
        .onDisappear {
            stopRound()
            if streamingManager.isStreaming {
                Task {
                    await stopLiveStreaming()
                }
            }
            setupPortraitOrientation()
        }
        .ignoresSafeArea()
    }
    
    // LiveKit 연결 및 스트리밍 시작
    private func startLiveStreaming() {
        Task {
            isLoading = true
            print("channelID", channelId)
            
            await viewModel.postLiveStream(channelId: channelId, place: "")
            
//             response의 status로 성공 여부 확인
            if viewModel.response.status == 200 {  // 또는 실제 API 응답의 성공 상태값
                print(self.viewModel.response.data?.id, "방송 id ")
                await connectToRoom()
                streamingManager.isStreaming = true
            } else {
                await MainActor.run {
                    errorMessage = "라이브 스트리밍을 시작할 수 없습니다. (\(viewModel.errorMessage ?? "알 수 없는 오류"))"
                    showErrorAlert = true
                }
            }
            
            isLoading = false
        }
    }
    
    // LiveKit 연결 해제 및 스트리밍 종료
    private func stopLiveStreaming() async -> Bool {
        isLoading = true
        
        // 라이브 스트리밍 종료 API 호출
        if let matchId = viewModel.response.data?.id {
            await viewModel.postEndLiveStream(matchId: matchId)
            
            if viewModel.response.status == 200 {
                do {
                    // 1. LiveKit 카메라 비활성화
                    let localParticipant = roomCtx.room.localParticipant
                    try await localParticipant.setCamera(enabled: false)
                    await localParticipant.unpublishAll()
                    
                    // 2. LiveKit 연결 해제
                    await roomCtx.disconnect()
                    
                    // 3. 캡처 세션 정지
                    StreamingManager.shared.stopPreviewSession()
                    
                    // 4. 스트리밍 상태 업데이트
                    streamingManager.isStreaming = false
                    
                    print("라이브 종료 완료")
                    isLoading = false
                    return true
                } catch {
                    print("카메라 비활성화 실패: \(error)")
                    // 에러 발생 시에도 연결 해제 시도
                    await roomCtx.disconnect()
                    StreamingManager.shared.stopPreviewSession()
                    streamingManager.isStreaming = false
                    isLoading = false
                    return true
                }
            } else {
                print("카메라 비활성화 실패 ")
            }
        }
        
        isLoading = false
        return false
    }
    
    // LiveKit 룸 연결
    private func connectToRoom() async {
        let livekitUrl = "wss://openvidufightclubsubdomain.click"
        let roomName = "myRoom"
        let participantName = "myMac"
        let applicationServerUrl = "http://43.201.27.173:6080"
        
        do {
            // 1. 토큰 획득
            let token = try await httpService.getToken(
                applicationServerUrl: applicationServerUrl,
                roomName: roomName,
                participantName: participantName)
            
            guard !token.isEmpty else {
                print("Received empty token")
                return
            }
            
            // 2. Room 설정
            roomCtx.token = token
            roomCtx.livekitUrl = livekitUrl
            roomCtx.name = roomName
            
            // 3. Room 연결
            try await roomCtx.connect()
            
            // 4. LiveKit 카메라 활성화 (후면 카메라)
            let localParticipant = roomCtx.room.localParticipant
            try await localParticipant.setCamera    (enabled: true, captureOptions: CameraCaptureOptions(position: .back))
            
            print("LiveKit room connected and camera enabled")
        } catch {
            print("Failed to connect to room: \(error)")
            streamingManager.isStreaming = false
        }
    }
    
    // 화면 방향 설정 함수들
    private func setupLandscapeOrientation() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
                if error != nil {
                    print("Failed to update geometry to landscape")
                }
            }
        }
        AppDelegate.orientationLock = .landscape
    }
    
    private func setupPortraitOrientation() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                if error != nil {
                    print("Failed to update geometry: \(error.localizedDescription ?? "")")
                }
            }
        }
        AppDelegate.orientationLock = .all
    }
    
    private func startRound() {
        isRoundActive = true
        remainingTime = 180
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                stopRound()
            }
        }
    }
    
    private func stopRound() {
        isRoundActive = false
        timer?.invalidate()
        timer = nil
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var chatOverlay: some View {
        VStack(spacing: 0) {
            Text("실시간 채팅")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.5))
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 8)
            }
            
            HStack(spacing: 8) {
                TextField("메시지 입력...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 14))
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(mainRed)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.3))
        }
    }
    
    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        let message = ChatMessage(id: UUID(), text: newMessage, isFromCurrentUser: true)
        messages.append(message)
        newMessage = ""
    }
}

struct CameraPreview: View {
    var body: some View {
        CameraPreviewRepresentable()
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let previewLayer = StreamingManager.shared.previewLayer
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .landscapeRight
        
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            let previewLayer = StreamingManager.shared.previewLayer
            previewLayer.frame = uiView.bounds
            previewLayer.connection?.videoOrientation = .landscapeRight
        }
    }
}

struct ControlButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color("mainRed"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 10)
        }
    }
}

struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isFromCurrentUser: Bool
}

struct ChatBubble: View {
    let message: ChatMessage
    private let mainRed = Color("mainRed")
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            Text(message.text)
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(message.isFromCurrentUser ? mainRed : Color.gray.opacity(0.3))
                )
                .foregroundColor(.white)
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
    }
}

struct StreamingView_Previews: PreviewProvider {
    static var previews: some View {
        let preferences = Preferences()
        let keychain = Keychain(service: "com.fightclub.app")
        let store = ValueStore(store: keychain, 
                             key: "preferences",
                             default: preferences)
        let roomContext = RoomContext(store: store)
        let appContext = AppContext(store: store)
        
        StreamingView(channelId: "12345")
            .environmentObject(roomContext)
            .environmentObject(appContext)
    }
}

