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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 카메라 프리뷰
                CameraPreview()
                    .ignoresSafeArea()
                
                // 채팅 오버레이
                VStack {
                    if isRoundActive {
                        // 타이머 표시
                        Text(timeString(from: remainingTime))
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    // 채팅 영역
                    HStack {
                        Spacer()
                        chatOverlay
                            .frame(width: geometry.size.width * 0.3)
                            .background(Color.black.opacity(0.5))
                    }
                }
                
                // 컨트롤 버튼들
                VStack {
                    Spacer()
                    HStack {
                        // 라운드 시작/종료 버튼
                        Button(action: {
                            if isRoundActive {
                                stopRound()
                            } else {
                                startRound()
                            }
                        }) {
                            Image(systemName: isRoundActive ? "stop.circle.fill" : "play.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(isRoundActive ? .red : .green)
                        }
                        .padding()
                        
                        // 라이브 스트리밍 시작/종료 버튼
                        Button(action: {
                            if isLiveStreaming {
                                stopLiveStreaming()
                            } else {
                                startLiveStreaming()
                            }
                        }) {
                            Image(systemName: isLiveStreaming ? "radio.fill" : "radio")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(isLiveStreaming ? .red : .white)
                        }
                        .padding()
                    }
                    .padding(.bottom, 30)
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
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                    }
                }
            }
            .padding()
            
            HStack {
                TextField("메시지 입력...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
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
        isLiveStreaming = false
        // 스트리밍 중지 로직
    }
    
    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        let message = ChatMessage(id: UUID(), text: newMessage, isFromCurrentUser: true)
        messages.append(message)
        newMessage = ""
    }
    
    private func connectToRoom() async {
        let livekitUrl = "wss://openvidufightclubsubdomain.click"
        let roomName = "myroom"
        let participantName = "powerades"
        let applicationServerUrl = "http://3.35.169.28:6080"

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
            
            // 카메라 활성화
            try await localParticipant.setCamera(enabled: true)
            
            print("Room connected and camera enabled")
        } catch {
            print("Failed to connect to room: \(error)")
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
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            Text(message.text)
                .padding()
                .background(message.isFromCurrentUser ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(15)
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
    }
}

struct CameraPreview: View {
    var body: some View {
        CameraPreviewRepresentable()
            .edgesIgnoringSafeArea(.all)
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        
        let captureSession = AVCaptureSession()
        
        // HD 해상도 설정
        captureSession.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("카메라를 찾을 수 없습니다")
            return view
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.connection?.videoOrientation = .landscapeRight
            
            view.layer.addSublayer(previewLayer)
            
            // 백그라운드에서 세션 시작
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
            
        } catch {
            print("카메라 설정 오류: \(error.localizedDescription)")
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = uiView.bounds
                previewLayer.connection?.videoOrientation = .landscapeRight
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
