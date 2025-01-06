//
//  StreamingView.swift
//  FightClub
//
//  Created by Edward Lee on 1/6/25.
//

import SwiftUI
import LiveKit
import AVFoundation

struct StreamingViewRepresentable<Content: View>: UIViewControllerRepresentable {
    let content: Content
    
    func makeUIViewController(context: Context) -> UIViewController {
        let hostingController = LandscapeHostingController(rootView: content)
        hostingController.modalPresentationStyle = .fullScreen
        return hostingController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

class LandscapeHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .landscapeRight
    }
    
    override var shouldAutorotate: Bool {
        false
    }
    
    override var prefersStatusBarHidden: Bool {
        true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfSupportedInterfaceOrientations()
        
        // 강제로 가로 방향으로 전환
        let value = UIInterfaceOrientation.landscapeRight.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppDelegate.AppUtility.lockOrientation(.landscape)
        
        // 가로 방향 강제
        let value = UIInterfaceOrientation.landscapeRight.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppDelegate.AppUtility.lockOrientation(.portrait)
        
        // 세로 방향으로 복귀
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
    }
}

extension AppDelegate {
    struct AppUtility {
        static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
            if let delegate = UIApplication.shared.delegate as? AppDelegate {
                delegate.orientationLock = orientation
            }
        }
    }
}

//#Preview {
//    StreamingView()
//        .environmentObject(RoomContext())
//        .environmentObject(AppContext())
//        .environmentObject(Room())
//}

struct StreamingView: View {
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var appCtx: AppContext
    @EnvironmentObject var room: Room
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLiveStreaming = false
    @State private var isRoundActive = false
    @State private var remainingTime: TimeInterval = 180 // 3 minutes
    @State private var timer: Timer?
    @State private var messages: [ChatMessage] = []
    @State private var newMessage = ""
    @State private var orientation = UIDevice.current.orientation
    
    var httpService = HTTPClient()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Camera Preview (Background)
                CameraPreview()
                    .ignoresSafeArea()
                
                // Main Content
                HStack(spacing: 0) {
                    // Left Controls
                    VStack(spacing: 20) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        
                        if isRoundActive {
                            Text(timeString(from: remainingTime))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(12)
                        }
                        
                        Spacer()
                        
                        // Round Control Button
                        Button(action: {
                            if isRoundActive {
                                stopRound()
                            } else {
                                startRound()
                            }
                        }) {
                            Text(isRoundActive ? "라운드 종료" : "라운드 시작")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 140)
                                .padding(.vertical, 12)
                                .background(Color.mainRed)
                                .cornerRadius(25)
                        }
                    }
                    .frame(width: geometry.size.width * 0.2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .background(Color.black.opacity(0.2))
                    
                    // Center Space (Camera View)
                    Spacer()
                    
                    // Right Side (Chat & Controls)
                    VStack(spacing: 16) {
                        // Live Streaming Button
                        Button(action: toggleLiveStreaming) {
                            Text(isLiveStreaming ? "방송 종료" : "방송 시작")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(isLiveStreaming ? Color.red : Color.mainRed)
                                .cornerRadius(25)
                        }
                        
                        // Chat Area
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(messages) { message in
                                    ChatBubble(message: message)
                                }
                            }
                            .padding()
                        }
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(16)
                        
                        // Message Input
                        HStack(spacing: 12) {
                            TextField("메시지 입력...", text: $newMessage)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(.white)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(20)
                            
                            Button(action: sendMessage) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color.mainRed)
                                    .clipShape(Circle())
                            }
                            .disabled(newMessage.isEmpty)
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(16)
                    }
                    .frame(width: geometry.size.width * 0.25)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .background(Color.black.opacity(0.2))
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            let value = UIInterfaceOrientation.landscapeRight.rawValue
            UIDevice.current.setValue(value, forKey: "orientation")
            AppDelegate.AppUtility.lockOrientation(.landscape)
        }
        .onDisappear {
            stopRound()
            let value = UIInterfaceOrientation.portrait.rawValue
            UIDevice.current.setValue(value, forKey: "orientation")
            AppDelegate.AppUtility.lockOrientation(.portrait)
        }
    }
    
    private func toggleLiveStreaming() {
        isLiveStreaming.toggle()
        if isLiveStreaming {
            Task {
                await connectToRoom()
            }
        } else {
            Task {
                await roomCtx.disconnect()
            }
        }
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
    
    private func sendMessage() {
        guard !newMessage.isEmpty else { return }
        let message = ChatMessage(id: UUID(), text: newMessage, isMe: true)
        messages.append(message)
        newMessage = ""
    }
    
    func connectToRoom() async {
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
                applicationServerUrl: applicationServerUrl, roomName: roomName,
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
            print("Room connected")
        } catch {
            print("Failed to connect to room: \(error)")
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let captureSession = AVCaptureSession()
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: backCamera) else {
            return view
        }
        
        captureSession.addInput(input)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .background).async {
            captureSession.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isMe: Bool
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        Text(message.text)
            .padding(8)
            .foregroundColor(.white)
            .background(Color.black.opacity(0.5))
            .cornerRadius(12)
    }
}
