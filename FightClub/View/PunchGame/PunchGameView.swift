//
//  PunchGameView.swift
//  FightClub
//
//  Created by Edward Lee on 1/14/25.
//

import SwiftUI
import AVFoundation
import LiveKit
import Network
import WatchConnectivity
import Foundation
import LiveKitWebRTC
import WebRTC

enum WebRTCError: Error {
    case invalidURL
    case invalidResponse
    case tokenError
    case webSocketError
}

class CustomPunchVideoCapturer: NSObject {
    private let captureSession = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "com.fightclub.capture", qos: .default)
    private let punchDetector = PunchDetector()
    private let webRTCManager = WebRTCManager.shared
    
    @Published var punchCount = 0
    @Published var showPunchEffect = false
    
    override init() {
        super.init()
        setupCaptureSession()
        captureQueue.async { [weak self] in
            self?.captureSession.startRunning()
            print("카메라 세션 시작됨")
        }
    }
    
    private func setupCaptureSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("카메라를 찾을 수 없음")
            return
        }
        
        do {
            captureSession.beginConfiguration()
            
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                print("카메라 입력 추가됨")
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
            print("샘플 버퍼 델리게이트 설정됨")
            
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
                print("비디오 출력 추가됨")
                
                if let connection = videoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = true
                    }
                    print("비디오 연결 설정됨")
                }
            }
            
            captureSession.commitConfiguration()
            print("카메라 설정 완료")
            
        } catch {
            print("카메라 설정 실패: \(error)")
        }
    }
    
    func stop() {
        captureQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                print("카메라 세션 중지")
            }
        }
    }
}

extension CustomPunchVideoCapturer: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("프레임 수신됨: \(Date())")
        
        // 1. 펀치 감지 수행
        punchDetector.detectPunch(in: sampleBuffer) { [weak self] isPunch in
            guard let self = self else { return }
            if isPunch {
                DispatchQueue.main.async {
                    self.punchCount += 1
                    self.showPunchEffect = true
                    print("펀치 감지! 현재 카운트: \(self.punchCount)")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.showPunchEffect = false
                    }
                }
            }
        }
        
        // 2. WebRTC로 프레임 전송
        webRTCManager.sendVideoFrame(sampleBuffer)
    }
}

// RTCVideoView를 SwiftUI에서 사용하기 위한 래퍼
struct WebRTCVideoView: UIViewRepresentable {
    let videoTrack: RTCVideoTrack?
    
    func makeUIView(context: Context) -> RTCMTLVideoView {
        let videoView = RTCMTLVideoView(frame: .zero)
        videoView.videoContentMode = .scaleAspectFill
        if let videoTrack = videoTrack {
            videoTrack.add(videoView)
        }
        return videoView
    }
    
    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        // 업데이트가 필요한 경우 구현
    }
}

// 펀치 카운터 뷰
struct PunchCounterView: View {
    let count: Int
    let isLocal: Bool
    let mainRed = Color("mainRed")
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .foregroundColor(mainRed)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isLocal ? "나의 펀치" : "상대방 펀치")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(count)")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.7))
                .shadow(color: mainRed.opacity(0.3), radius: 10, x: 0, y: 5)
        )
    }
}

// 메인 뷰 수정
struct PunchGameView: View {
    @StateObject private var gameManager = PunchGameManager.shared
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var isConnected = false
    @State private var remoteCount = 0 // 상대방 펀치 카운트
    
    private let mainRed = Color("mainRed")
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // 상대방 비디오 뷰
                    ZStack {
                        if isConnected {
                            WebRTCVideoView(videoTrack: WebRTCManager.shared.remoteVideoTrack)
                        } else {
                            Text("상대방 대기 중...")
                                .foregroundColor(.white)
                        }
                        
                        // 상대방 펀치 카운터
                        VStack {
                            Spacer()
                            HStack {
                                PunchCounterView(count: remoteCount, isLocal: false)
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    .frame(height: geometry.size.height * 0.5)
                    
                    // 중앙 구분선
                    Rectangle()
                        .fill(mainRed.opacity(0.3))
                        .frame(height: 1)
                        .padding(.horizontal)
                    
                    // 내 비디오 뷰
                    ZStack {
                        if isConnected {
                            WebRTCVideoView(videoTrack: WebRTCManager.shared.localVideoTrack)
                        } else {
                            Text("카메라 초기화 중...")
                                .foregroundColor(.white)
                        }
                        
                        // 내 펀치 카운터
                        VStack {
                            Spacer()
                            HStack {
                                PunchCounterView(count: gameManager.punchCount, isLocal: true)
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    .frame(height: geometry.size.height * 0.5)
                }
                
                // 펀치 효과 오버레이
                if gameManager.showPunchEffect {
                    Color.red
                        .opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.2), value: gameManager.showPunchEffect)
                }
                
                // 로딩 오버레이
                if isLoading {
                    PunchGameLoadingView()
                }
            }
        }
        .alert("오류", isPresented: $showErrorAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            initializeWebRTC()
        }
        .onDisappear {
            cleanupWebRTC()
        }
    }
}

// 로딩 뷰
struct PunchGameLoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("연결 중...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}

extension PunchGameView {
    private func initializeWebRTC() {
        Task {
            isLoading = true
            
            do {
                print("WebRTC 초기화 시작...")
                try await WebRTCManager.shared.connect()
                
                await MainActor.run {
                    isConnected = true
                    isLoading = false
                }
                
                print("WebRTC 초기화 완료")
                
            } catch {
                print("WebRTC 초기화 실패: \(error)")
                await MainActor.run {
                    errorMessage = "연결 실패: \(error.localizedDescription)"
                    showErrorAlert = true
                    isLoading = false
                }
            }
        }
    }
    
    private func cleanupWebRTC() {
        Task {
            do {
                print("WebRTC 정리 시작...")
                
                // 펀치 감지 세션 중지
                gameManager.stopCapturing()
                
                await MainActor.run {
                    isConnected = false
                }
                
                print("WebRTC 정리 완료")
                
            } catch {
                print("WebRTC 정리 중 오류 발생: \(error)")
            }
        }
    }
}

struct PunchCameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        print("카메라 프리뷰 뷰 생성")
        let view = UIView()
        view.backgroundColor = .black
        
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        print("카메라 프리뷰 뷰 업데이트")
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}

struct SampleBufferVideoView: UIViewRepresentable {
    let displayLayer: AVSampleBufferDisplayLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        displayLayer.frame = view.bounds
        view.layer.addSublayer(displayLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        displayLayer.frame = uiView.bounds
    }
}

class PunchGameManager: NSObject, ObservableObject {
    static let shared = PunchGameManager()
    private let customCapturer = CustomPunchVideoCapturer()
    
    @Published var punchCount: Int = 0
    @Published var showPunchEffect: Bool = false
    
    private override init() {
        super.init()
        
        // 펀치 카운트와 효과를 커스텀 캡처러와 연동
        customCapturer.$punchCount
            .assign(to: &$punchCount)
        
        customCapturer.$showPunchEffect
            .assign(to: &$showPunchEffect)
    }
    
    func getCapturer() -> CustomPunchVideoCapturer {
        return customCapturer
    }
    
    func stopCapturing() {
        customCapturer.stop()
    }
}


class WebRTCManager: NSObject {
    static let shared = WebRTCManager()
    
    private let factory: RTCPeerConnectionFactory
    private let peerConnection: RTCPeerConnection
    private let videoSource: RTCVideoSource
    private let videoCapturer: RTCCameraVideoCapturer
    
    // OpenVidu 설정
    private let serverURL = "https://openvidufightclubsubdomain.click"
    private let wsURL = "wss://openvidufightclubsubdomain.click:4443"
    private let tokenServerURL = "http://43.201.27.173:6080"
    private let roomName = "punchGame"
    private let participantName = "User-\(Int.random(in: 1000...9999))"
    
    private var webSocket: URLSessionWebSocketTask?
    
    private(set) var localVideoTrack: RTCVideoTrack?
    private(set) var remoteVideoTrack: RTCVideoTrack?
    
    private override init() {
        // WebRTC 초기화
        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
        
        // 미디어 스트림 설정
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )
        
        // ICE 서버 설정
        let configuration = RTCConfiguration()
        configuration.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]
        
        // PeerConnection 생성
        peerConnection = factory.peerConnection(
            with: configuration,
            constraints: constraints,
            delegate: nil
        )!
        
        // 비디오 소스 및 캡처러 설정
        videoSource = factory.videoSource()
        videoCapturer = RTCCameraVideoCapturer(delegate: videoSource as! RTCVideoCapturerDelegate)
        
        super.init()
        
        // delegate 설정
        peerConnection.delegate = self
    }
    
    deinit {
        RTCCleanupSSL()
    }
    
    func connect() async throws {
        // 토큰 요청 URL (기존 URL 유지)
        let tokenURL = "http://43.201.27.173:6080/token"
        let requestBody = [
            "roomName": "punchGame",
            "participantName": "User-\(UUID().uuidString.prefix(4))"
        ]
        
        // 토큰 요청
        guard let url = URL(string: tokenURL),
              let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw WebRTCError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebRTCError.invalidResponse
        }
        
        print("📡 토큰 응답 코드: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200,
              let tokenResponse = try? JSONDecoder().decode(TokenResponseRTC.self, from: data),
              let token = tokenResponse.token else {
            throw WebRTCError.tokenError
        }
        
        print("✅ 토큰 획득 성공: \(token)")
        
        // WebSocket URL을 OpenVidu 형식으로 수정
        let wsURL = "wss://openvidufightclubsubdomain.click:4443/openvidu?sessionId=punchGame&token=\(token)"
        guard let webSocketURL = URL(string: wsURL) else {
            throw WebRTCError.invalidURL
        }
        
        print("🔗 WebSocket URL: \(wsURL)")
        
        // WebSocket 연결
        let urlSession = URLSession(configuration: .default)
        webSocket = urlSession.webSocketTask(with: webSocketURL)
        webSocket?.resume()
        
        print("🌐 WebSocket 연결 시작...")
        
        // 메시지 수신 대기
        receiveMessage()
        
        // Ping 타이머 설정
        setupPingTimer()
        
        print("✅ OpenVidu 연결 설정 완료")
        
        // joinRoom 메시지 전송
        let joinMessage = [
            "id": "joinRoom",
            "session": "punchGame",
            "platform": "iOS",
            "token": token,
            "metadata": "{\"clientData\": \"iOS-User\"}"
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: joinMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webSocket?.send(.string(jsonString)) { error in
                if let error = error {
                    print("❌ joinRoom 메시지 전송 실패: \(error.localizedDescription)")
                } else {
                    print("✅ joinRoom 메시지 전송 성공")
                }
            }
        }
    }
    
    func sendVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("❌ pixelBuffer 변환 실패")
            return 
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let timeStampNs = Int64(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * Double(NSEC_PER_SEC))
        
        if let capturer = videoCapturer as? RTCCameraVideoCapturer {
            print("📸 프레임 정보:")
            print("- 크기: \(width)x\(height)")
            print("- 타임스탬프: \(timeStampNs)")
            
            let videoFrame = RTCVideoFrame(
                buffer: RTCCVPixelBuffer(pixelBuffer: pixelBuffer),
                rotation: ._0,
                timeStampNs: timeStampNs
            )
            
            capturer.delegate?.capturer(capturer, didCapture: videoFrame)
            print("✅ WebRTC 프레임 전송 완료")
        } else {
            print("❌ RTCCameraVideoCapturer 캐스팅 실패")
        }
    }
    
    func receiveMessage() {
        print("🔄 메시지 수신 대기 시작")
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                print("✅ 메시지 수신 성공")
                switch message {
                case .string(let text):
                    print("📨 수신된 메시지: \(text)")
                    
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        // OpenVidu 메시지 처리
                        self.handleOpenViduMessage(json)
                    }
                    
                case .data(let data):
                    print("시그널링 데이터 수신: \(data)")
                @unknown default:
                    break
                }
                
                // 다음 메시지 수신 대기
                self.receiveMessage()
                
            case .failure(let error):
                print("❌ 메시지 수신 실패: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleOpenViduMessage(_ message: [String: Any]) {
        print("📨 OpenVidu 메시지 수신: \(message)") // 디버그 로그 추가
        
        if let id = message["id"] as? String {
            switch id {
            case "room-connected":
                print("✅ 방 연결 성공")
                if let participants = message["participants"] as? [[String: Any]] {
                    print("현재 참가자 수: \(participants.count)")
                    print("참가자 정보: \(participants)")
                }
                createOffer()
                
            case "participantJoined":
                print("✅ 새로운 참가자 입장")
                if let metadata = message["metadata"] as? String {
                    print("참가자 메타데이터: \(metadata)")
                }
                
            case "receiveVideoAnswer":
                print("✅ Video Answer 수신")
                if let sdpString = message["sdpAnswer"] as? String {
                    let sdp = RTCSessionDescription(type: .answer, sdp: sdpString)
                    peerConnection.setRemoteDescription(sdp) { error in
                        if let error = error {
                            print("❌ Remote Description 설정 실패: \(error.localizedDescription)")
                        } else {
                            print("✅ Remote Description 설정 성공")
                        }
                    }
                }
                
            case "iceCandidate":
                print("✅ ICE Candidate 수신")
                if let candidate = message["candidate"] as? [String: Any] {
                    print("ICE Candidate 정보: \(candidate)")
                    if let sdp = candidate["candidate"] as? String,
                       let sdpMid = candidate["sdpMid"] as? String,
                       let sdpMLineIndex = candidate["sdpMLineIndex"] as? Int32 {
                        
                        let iceCandidate = RTCIceCandidate(
                            sdp: sdp,
                            sdpMLineIndex: sdpMLineIndex,
                            sdpMid: sdpMid
                        )
                        peerConnection.add(iceCandidate)
                        print("✅ ICE Candidate 추가됨")
                    }
                }
                
            default:
                print("⚠️ 처리되지 않은 메시지 ID: \(id)")
                print("메시지 전체 내용: \(message)")
            }
        } else {
            print("❌ 메시지에 ID가 없음: \(message)")
        }
    }
    
    private func createOffer() {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveVideo": "true",
                "OfferToReceiveAudio": "false"
            ],
            optionalConstraints: nil
        )
        
        peerConnection.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self,
                  let sdp = sdp else {
                print("❌ Offer 생성 실패: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            
            peerConnection.setLocalDescription(sdp) { error in
                if let error = error {
                    print("❌ Local Description 설정 실패: \(error.localizedDescription)")
                    return
                }
                
                // Offer를 서버로 전송
                let offerMessage = [
                    "jsonrpc": "2.0",
                    "method": "receiveVideoFrom",
                    "params": [
                        "sender": self.participantName,
                        "sdpOffer": sdp.sdp
                    ]
                ] as [String : Any]
                
                if let jsonData = try? JSONSerialization.data(withJSONObject: offerMessage),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    self.webSocket?.send(.string(jsonString)) { error in
                        if let error = error {
                            print("❌ Offer 전송 실패: \(error.localizedDescription)")
                        } else {
                            print("✅ Offer 전송 성공")
                        }
                    }
                }
            }
        }
    }
    
    func disconnect() {
        webSocket?.cancel()
        webSocket = nil
    }
    
    func startPingTimer() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            let pingMessage = ["id": "ping"]
            if let jsonData = try? JSONSerialization.data(withJSONObject: pingMessage),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                self?.webSocket?.send(.string(jsonString)) { error in
                    if let error = error {
                        print("❌ Ping 전송 실패: \(error.localizedDescription)")
                    } else {
                        print("✅ Ping 전송 성공")
                    }
                }
            }
        }
    }
    
    private func setupPingTimer() {
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        let pingMessage = ["id": "ping"]
        if let jsonData = try? JSONSerialization.data(withJSONObject: pingMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webSocket?.send(.string(jsonString)) { error in
                if let error = error {
                    print("❌ Ping 전송 실패: \(error.localizedDescription)")
                }
            }
        }
    }
}

// RTCPeerConnectionDelegate 구현 수정
extension WebRTCManager: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("didRemove")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("peerConnection")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("🔄 시그널링 상태: \(stateChanged.rawValue)")
    }
    
    // didAdd 대신 didRemove로 수정
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("스트림 제거됨")
    }
    
    // 필수 메서드 추가
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd receiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        print("➕ 스트림 추가됨:")
        print("- 미디어 스트림 수: \(mediaStreams.count)")
        if let videoTrack = receiver.track as? RTCVideoTrack {
            self.remoteVideoTrack = videoTrack
            print("✅ 비디오 트랙 설정 완료")
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let iceCandidateMessage = [
            "jsonrpc": "2.0",
            "method": "onIceCandidate",
            "params": [
                "endpointName": participantName,
                "candidate": [
                    "candidate": candidate.sdp,
                    "sdpMid": candidate.sdpMid,
                    "sdpMLineIndex": candidate.sdpMLineIndex
                ]
            ]
        ] as [String : Any]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: iceCandidateMessage),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webSocket?.send(.string(jsonString)) { error in
                if let error = error {
                    print("❌ ICE candidate 전송 실패: \(error.localizedDescription)")
                } else {
                    print("✅ ICE candidate 전송 성공")
                }
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("🌐 ICE 연결 상태: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("ICE 수집 상태 변경: \(newState.rawValue)")
    }
    
    // 필수 메서드 추가
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("연결 재협상 시작...")
        
        // 1. Offer 생성
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveVideo": "true",
                "OfferToReceiveAudio": "false"
            ],
            optionalConstraints: nil
        )
        
        peerConnection.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self,
                  let sdp = sdp else {
                print("❌ Offer 생성 실패: \(error?.localizedDescription ?? "unknown error")")
                return
            }
            
            print("✅ Offer 생성 성공")
            
            // 2. Local Description 설정
            peerConnection.setLocalDescription(sdp) { error in
                if let error = error {
                    print("❌ Local Description 설정 실패: \(error.localizedDescription)")
                    return
                }
                
                print("✅ Local Description 설정 성공")
                
                // 3. Offer를 시그널링 서버로 전송
                let offerMessage = [
                    "type": "offer",
                    "sdp": sdp.sdp
                ]
                
                if let jsonData = try? JSONSerialization.data(withJSONObject: offerMessage),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    self.webSocket?.send(.string(jsonString)) { error in
                        if let error = error {
                            print("❌ Offer 전송 실패: \(error.localizedDescription)")
                        } else {
                            print("✅ Offer 전송 성공")
                        }
                    }
                }
            }
        }
    }
    
    // 필수 메서드 추가
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("ICE candidate 제거됨")
    }
}
