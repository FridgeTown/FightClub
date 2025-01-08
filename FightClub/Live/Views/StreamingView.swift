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

struct StreamingView: View {
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var appCtx: AppContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLiveStreaming = false
    @State private var isRoundActive = false
    @State private var remainingTime: TimeInterval = 180 // 3 minutes
    @State private var timer: Timer?
    @State private var messages: [ChatMessage] = []
    @State private var newMessage = ""
    
    var httpService = HTTPClient()
    private let mainRed = Color("mainRed")
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 카메라 프리뷰
                CameraPreview(isLiveStreaming: $isLiveStreaming)
                    .ignoresSafeArea()
                
                // 상단 오버레이
                VStack {
                    if isRoundActive {
                        // 타이머 표시
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
                        // 라운드 시작/종료 버튼
                        ControlButton(
                            icon: isRoundActive ? "stop.circle.fill" : "play.circle.fill",
                            color: isRoundActive ? .red : .green,
                            action: {
                                if isRoundActive {
                                    stopRound()
                                } else {
                                    startRound()
                                }
                            }
                        )
                        
                        // 라이브 스트리밍 시작/종료 버튼
                        ControlButton(
                            icon: isLiveStreaming ? "record.circle.fill" : "record.circle",
                            color: isLiveStreaming ? mainRed : .white,
                            action: {
                                if isLiveStreaming {
                                    stopLiveStreaming()
                                } else {
                                    startLiveStreaming()
                                }
                            }
                        )
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            // 가로 방향으로 강제 회전
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
                    if error != nil {
                        print("Failed to update geometry to landscape")
                    }
                }
            }
            AppDelegate.orientationLock = .landscape
        }
        .onDisappear {
            stopRound()
            // 세로 방향으로 복귀
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                    if error != nil {
                        print("Failed to update geometry to portrait")
                    }
                }
            }
            AppDelegate.orientationLock = .all
        }
        .ignoresSafeArea()
    }
    
    private var chatOverlay: some View {
        VStack(spacing: 0) {
            // 채팅 헤더
            Text("실시간 채팅")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.5))
            
            // 채팅 메시지
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // 메시지 입력
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
    
    private func startRound() {
        isRoundActive = true
        remainingTime = 180 // 3분
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
    
    private func startLiveStreaming() {
        Task {
            await connectToRoom()
            isLiveStreaming = true
        }
    }
    
    private func stopLiveStreaming() {
        Task {
            // 카메라 비활성화
            let localParticipant = roomCtx.room.localParticipant
            try? await localParticipant.setCamera(enabled: false)
            // 룸 연결 해제
            await roomCtx.disconnect()
            
            // 프리뷰 카메라 재시작
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isLiveStreaming = false
            }
        }
    }
    
    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        let message = ChatMessage(id: UUID(), text: newMessage, isFromCurrentUser: true)
        messages.append(message)
        newMessage = ""
    }
    
    private func connectToRoom() async {
        let livekitUrl = "wss://openvidufightclubsubdomain.click"
        let roomName = "myRoom"
        let participantName = "myMac"
        let applicationServerUrl = "http://43.201.27.173:6080"

        guard !livekitUrl.isEmpty, !roomName.isEmpty else {
            print("LiveKit URL or room name is empty")
            return
        }

        do {
            let token = try await httpService.getToken(
                applicationServerUrl: applicationServerUrl, 
                roomName: roomName,
                participantName: participantName)

            if token.isEmpty {
                print("Received empty token")
                return
            }

            roomCtx.token = token
            roomCtx.livekitUrl = livekitUrl
            roomCtx.name = roomName
            
            print("Connecting to room...")
            try await roomCtx.connect()
            
            // 비디오 트랙 설정
            let localParticipant = roomCtx.room.localParticipant
            try await localParticipant.setCamera(enabled: true)
            
            print("Room connected and camera enabled")
        } catch {
            print("Failed to connect to room: \(error)")
        }
    }
}

struct ControlButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(color)
                .padding(12)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.5), lineWidth: 2)
                        )
                )
                .shadow(color: color.opacity(0.3), radius: 10)
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

struct CameraPreview: View {
    @Binding var isLiveStreaming: Bool
    
    var body: some View {
        CameraPreviewRepresentable(isLiveStreaming: $isLiveStreaming)
            .edgesIgnoringSafeArea(.all)
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable {
    @Binding var isLiveStreaming: Bool
    let captureSession = AVCaptureSession()
    let previewLayer: AVCaptureVideoPreviewLayer
    
    init(isLiveStreaming: Binding<Bool>) {
        self._isLiveStreaming = isLiveStreaming
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        // 세션 설정을 초기화 시점에 수행
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        // HD 해상도 설정
        captureSession.sessionPreset = .high
        
        // 후면 카메라 명시적 설정
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("후면 카메라를 찾을 수 없습니다")
            return
        }
        
        do {
            // 기존 입력 제거
            captureSession.inputs.forEach { captureSession.removeInput($0) }
            
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            // 백그라운드에서 세션 시작
            DispatchQueue.global(qos: .userInitiated).async {
                if !captureSession.isRunning {
                    captureSession.startRunning()
                }
            }
        } catch {
            print("카메라 설정 오류: \(error.localizedDescription)")
        }
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .landscapeRight
        
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
            previewLayer.connection?.videoOrientation = .landscapeRight
            
            // LiveStreaming 상태에 따라 카메라 프리뷰 세션 제어
            if isLiveStreaming {
                if captureSession.isRunning {
                    DispatchQueue.global(qos: .userInitiated).async {
                        captureSession.stopRunning()
                    }
                }
            } else {
                if !captureSession.isRunning {
                    DispatchQueue.global(qos: .userInitiated).async {
                        captureSession.startRunning()
                    }
                }
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
        
        StreamingView()
            .environmentObject(roomContext)
            .environmentObject(appContext)
    }
}
