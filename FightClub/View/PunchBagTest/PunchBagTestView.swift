//
//  PunchBagTestView.swift
//  FightClub
//
//  Created by Edward Lee on 1/15/25.
//

import SwiftUI
import LiveKit
import HealthKit
import AVFoundation

// MARK: - Room Delegate
final class GameRoomDelegate: NSObject, RoomDelegate {
    weak var viewModel: PunchBagTestViewModel?
    var onVideoTrackPublished: ((VideoTrack) -> Void)?
    
    func room(_ room: Room, participant: RemoteParticipant, didPublishTrack publication: RemoteTrackPublication) {
        print("Remote participant published track: \(publication.name)")
        print("Track kind: \(publication.kind)")
        print("Remote participant identity: \(participant.identity?.description)")
        
        if publication.kind == .video {
            print("Found video track, attempting to get VideoTrack instance")
            if let track = publication.track as? VideoTrack {
                print("Successfully got VideoTrack instance")
                Task { @MainActor in
                    onVideoTrackPublished?(track)
                    print("Video track published callback executed")
                }
            } else {
                Task {
                    for _ in 0..<6 {
                        if let track = publication.track as? VideoTrack {
                            await MainActor.run {
                                onVideoTrackPublished?(track)
                                print("Video track subscribed and published")
                            }
                            break
                        }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                }
            }
        }
        
        viewModel?.checkReadyState(in: room)
    }
    
    func room(_ room: Room, participant: RemoteParticipant, didUnpublishTrack publication: RemoteTrackPublication) {
        print("Remote participant unpublished track: \(publication.name)")
        viewModel?.checkReadyState(in: room)
    }
    
    func room(_ room: Room, didDisconnectWithError error: Error?) {
        print("Room disconnected with error: \(error?.localizedDescription ?? "none")")
        viewModel?.isReadyToStart = false
        viewModel?.isOpponentConnected = false
        viewModel?.checkGameStart()
    }
    
    func room(_ room: Room, participant: RemoteParticipant, didSubscribeTrack publication: RemoteTrackPublication) {
        print("Did subscribe to track: \(publication.name)")
        viewModel?.checkReadyState(in: room)
    }
    
    func room(_ room: Room, participant: RemoteParticipant, didUnsubscribeTrack publication: RemoteTrackPublication) {
        print("Did unsubscribe from track: \(publication.name)")
        viewModel?.checkReadyState(in: room)
    }
    
    func room(_ room: Room, didAdd participant: RemoteParticipant) {
        print("Did add participant: \(participant.identity?.description ?? "unknown")")
        viewModel?.participantDidJoin(participant)
    }
    
    func room(_ room: Room, didRemove participant: RemoteParticipant) {
        print("Did remove participant: \(participant.identity?.description ?? "unknown")")
        viewModel?.participantDidLeave(participant)
    }
    
    func room(_ room: Room, didReceiveData data: Data, participant: Participant?) {
        guard let receivedString = String(data: data, encoding: .utf8) else { return }
        
        Task {
            if receivedString == "READY" {
                if let vm: PunchBagTestViewModel = viewModel {
                    await vm.startCountdown()
                }
            }
        }
    }
    
    func room(_ room: Room, participant: RemoteParticipant, didPublishAudioTrack publication: RemoteTrackPublication) {
        print("Remote participant published audio track: \(publication.name)")
        print("Track kind: \(publication.kind)")
        print("Remote participant identity: \(participant.identity?.description)")
        
        if let track = publication.track as? AudioTrack {
            print("Found audio track, attempting to get AudioTrack instance")
            Task { @MainActor in
                onAudioTrackPublished?(track)
                print("Audio track published callback executed")
            }
        } else {
            Task {
                for _ in 0..<6 {
                    if let track = publication.track as? AudioTrack {
                        await MainActor.run {
                            onAudioTrackPublished?(track)
                            print("Audio track subscribed and published")
                        }
                        break
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
        
        viewModel?.checkReadyState(in: room)
    }
    
    func room(_ room: Room, participant: RemoteParticipant, didUnpublishAudioTrack publication: RemoteTrackPublication) {
        print("Remote participant unpublished audio track: \(publication.name)")
        viewModel?.checkReadyState(in: room)
    }
    
    var onAudioTrackPublished: ((AudioTrack) -> Void)?
}

// MARK: - Stats Item View
struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct PunchBagTestView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var gameManager = PunchGameManager.shared
    @StateObject private var viewModel = PunchBagTestViewModel()
    @StateObject private var punchBagTestModel = PunchBagTestModel()
    
    @EnvironmentObject var roomCtx: RoomContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var isConnected = false
    @State private var showExitAlert = false
    @State private var gameTimer: Timer?
    @State private var remainingTime: Int = 20
    @State private var isGameTimerRunning = false
    @State private var navigateToResult = false
    
    private let roomDelegate = GameRoomDelegate()
    let channelId: String
    
    private let mainRed = Color("mainRed")
    private let gradientStart = Color.black
    private let gradientEnd = Color(red: 0.2, green: 0.0, blue: 0.0)
    
    @State private var videoTrack: VideoTrack?
    @State private var isTestMode = false
    @State private var isDummyVideoEnabled = true
    
    // HTTP 클라이언트 추가
    var httpService = HTTPClient()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                
                VStack(spacing: 1) {
                    remoteVideoView(geometry: geometry)
                    dividerView
                    localVideoView(geometry: geometry)
                }
                
//                connectionStatusOverlay
                gameControlOverlay
            }
            .overlay(backButton, alignment: .topLeading)
            .alert("오류", isPresented: $showErrorAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("연습을 종료하시겠습니까?", isPresented: $showExitAlert) {
                Button("취소", role: .cancel) { }
                Button("종료", role: .destructive) {
                    cleanupSession()
                    dismiss()
                }
            } message: {
                Text("현재 진행 중인 연습이 종료되며, 상대방과의 연결이 끊어집니다.")
            }
            .onChange(of: navigateToResult) { newValue in
                if newValue {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .onAppear {
                setupSession()
            }
            .onDisappear {
                cleanupSession()
                viewModel.disconnectAll()
            }
        }
    }
    
    // MARK: - Subviews
    private var backgroundView: some View {
        LinearGradient(gradient: Gradient(colors: [gradientStart, gradientEnd]),
                      startPoint: .top,
                      endPoint: .bottom)
            .edgesIgnoringSafeArea(.all)
    }
    
    private var connectionStatusOverlay: some View {
        VStack {
            HStack {
                Image(systemName: viewModel.isWebSocketConnected ? "circle.fill" : "circle")
                    .foregroundColor(viewModel.isWebSocketConnected ? .green : .gray)
                Text("나의 연결")
                
                Spacer()
                    .frame(width: 20)
                
                Image(systemName: viewModel.isOpponentConnected ? "circle.fill" : "circle")
                    .foregroundColor(viewModel.isOpponentConnected ? .green : .gray)
                Text("상대방 연결")
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(10)
            .padding()
            
            Spacer()
        }
    }
    
    private var gameControlOverlay: some View {
        ZStack {
            if !viewModel.showCountdown && !viewModel.gameStarted {
                startButtonOverlay
            }
            
            if viewModel.showCountdown {
                countdownOverlay
            }
            
            if isGameTimerRunning {
                gameTimerOverlay
            }
        }
    }
    
    private var startButtonOverlay: some View {
        Color.black.opacity(0.5)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                VStack {
                    Spacer()
                    if viewModel.isReadyToStart {
                        Text("상대방과 매칭되었습니다!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                    }
                    
                    startButton
                    
                    if viewModel.isReady && !viewModel.isOpponentReady {
                        Text("상대방의 준비를 기다리는 중...")
                            .foregroundColor(.white)
                            .padding(.top, 8)
                    }
                    
                    Spacer()
                }
            )
    }
    
    private var startButton: some View {
        Button(action: startButtonAction) {
            Text(viewModel.isReady ? "준비 완료" : "게임 시작")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(width: 200)
                .background(viewModel.isReady ? Color.green : Color.mainRed)
                .cornerRadius(10)
        }
        .disabled(!isButtonEnabled)
    }
    
    private var isButtonEnabled: Bool {
        if viewModel.isTestMode {
            return isConnected && !roomCtx.room.remoteParticipants.isEmpty && !viewModel.isReady
        } else {
            return isConnected && 
                   !roomCtx.room.remoteParticipants.isEmpty && 
                   !roomCtx.room.localParticipant.videoTracks.isEmpty &&
                   !viewModel.isReady
        }
    }
    
    private var countdownOverlay: some View {
        Color.black.opacity(0.7)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                Text("\(viewModel.countdownValue)")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundColor(.white)
                    .transition(.scale)
                    .animation(.easeInOut, value: viewModel.countdownValue)
            )
    }
    
    private var gameTimerOverlay: some View {
        VStack {
            Spacer()
            ZStack {
                // 외부 원형 프로그레스 바
                Circle()
                    .stroke(lineWidth: 15)
                    .foregroundColor(Color.black.opacity(0.3))
                    .overlay(
                        Circle()
                            .trim(from: 0, to: CGFloat(remainingTime) / 20.0)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [mainRed, Color.orange]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 15, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    )
                
                // 내부 시간 표시
                VStack(spacing: 4) {
                    Text("\(remainingTime)")
                        .font(.system(size: 60, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: mainRed.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    Text("남은 시간")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 200, height: 200)
            .padding(.bottom, 50)
        }
    }
    
    private var backButton: some View {
        Button(action: { showExitAlert = true }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(12)
                .background(Circle().fill(Color.black.opacity(0.6)))
        }
        .padding(.leading, 20)
        .padding(.top, 40)
    }
    
    // MARK: - Video Views
    private func remoteVideoView(geometry: GeometryProxy) -> some View {
        ZStack {
            if isConnected {
                if let track = videoTrack {
                    SwiftUIVideoView(track, layoutMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    waitingView
                        .onAppear {
                            Task {
                                await findVideoTrack()
                            }
                        }
                }
            } else {
                waitingView
            }
            
            // 상대방 정보 오버레이
            VStack {
                Spacer()
                HStack {
                    opponentStatsView
                    Spacer()
                }
                .padding()
            }
        }
        .frame(height: geometry.size.height * 0.5)
        .padding(.horizontal)
        .padding(.top)
    }
    
    private func localVideoView(geometry: GeometryProxy) -> some View {
        ZStack {
            if isConnected {
                if viewModel.isTestMode {
                    dummyVideoView
                } else if let publication = roomCtx.room.localParticipant.videoTracks.first {
                    LiveKitVideoView(publication: publication)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(mainRed.opacity(0.3), lineWidth: 1)
                        )
                }
            } else {
                Color.black.opacity(0.6)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            
            // 내 정보 오버레이
            VStack {
                Spacer()
                HStack {
                    myStatsView
                    Spacer()
                }
                .padding()
            }
        }
        .frame(height: geometry.size.height * 0.5)
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private var dividerView: some View {
        HStack {
            Rectangle()
                .fill(mainRed.opacity(0.3))
                .frame(height: 1)
            Image(systemName: "bolt.fill")
                .foregroundColor(mainRed)
                .background(
                    Circle()
                        .fill(Color.black)
                        .frame(width: 30, height: 30)
                )
            Rectangle()
                .fill(mainRed.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal)
    }
    
    private var waitingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 60))
                .foregroundColor(mainRed)
            Text(viewModel.isTestMode ? "테스트 모드: 상대방 참가 대기 중..." : "상대방을 기다리는 중...")
                .font(.title3)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 2)
            
            if viewModel.isTestMode {
                Text("Room: \(roomCtx.name)")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("참가자 수: \(roomCtx.room.remoteParticipants.count + 1)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(0.6)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        )
    }
    
    // MARK: - Session Methods
    private func setupSession() {
        isLoading = true
        
        Task {
            do {
                // 시뮬레이터 감지 및 테스트 모드 설정
                #if targetEnvironment(simulator)
                viewModel.isTestMode = true
                print("Running in simulator mode")
                #else
                viewModel.isTestMode = false
                print("Running on real device")
                #endif
                
                // 1. LiveKit 룸 연결
                try await connectToRoom()
                
                // 2. 카메라 및 마이크 활성화
                if !viewModel.isTestMode {
                    try await roomCtx.room.localParticipant.setCamera(enabled: true)
                    try await roomCtx.room.localParticipant.setMicrophone(enabled: true)
                }
                
                // 3. 룸 델리게이트 설정 및 상태 업데이트
                await MainActor.run {
                    isConnected = true
                    isLoading = false
                    setupRoomDelegate()
                }
                
                // 4. 원격 비디오 트랙 찾기
                await findVideoTrack()
                
                // 5. 게임 타이머 설정
                setupGameTimer()
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                    isLoading = false
                    isConnected = false
                }
            }
        }
        
        healthKitManager.startWorkoutSession()
    }
    
    private func cleanupSession() {
        Task {
            do {
                // 1. 게임 타이머 정리
                gameTimer?.invalidate()
                gameTimer = nil
                
                // 2. 카메라와 마이크 비활성화
                if !viewModel.isTestMode {
                    try await roomCtx.room.localParticipant.setCamera(enabled: false)
                    try await roomCtx.room.localParticipant.setMicrophone(enabled: false)
                }
                
                // 3. 모든 트랙 언퍼블리시
                await roomCtx.room.localParticipant.unpublishAll()
                
                // 4. 룸 연결 해제
                await roomCtx.disconnect()
                
                // 5. 상태 초기화
                await MainActor.run {
                    isConnected = false
                    videoTrack = nil
                }
            } catch {
                print("LiveKit 연결 해제 중 오류 발생: \(error)")
            }
        }
        
        healthKitManager.stopWorkoutSession()
        viewModel.disconnectAll()
    }
    
    private func findVideoTrack() async {
        print("Starting findVideoTrack")
        print("Remote participants count: \(roomCtx.room.remoteParticipants.count)")
        
        for attempt in 1...5 {
            print("Attempt \(attempt) to find video track")
            
            if let participant = roomCtx.room.remoteParticipants.values.first {
                print("Found remote participant: \(participant.identity?.description)")
                
                for publication in participant.videoTracks {
                    if let track = publication.track as? VideoTrack {
                        print("Successfully found video track")
                        await MainActor.run {
                            self.videoTrack = track
                            print("Video track assigned to view")
                        }
                        return
                    }
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            } else {
                print("No remote participants found")
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        print("Failed to find video track after 5 attempts")
    }
    
    private func setupRoomDelegate() {
        print("Setting up room delegate")
        roomDelegate.viewModel = viewModel
        viewModel.room = roomCtx.room
        roomDelegate.onVideoTrackPublished = { track in
            print("Video track publish callback received")
            Task { @MainActor in
                videoTrack = track
                print("Video track assigned in callback")
            }
        }
        
        // 오디오 트랙 델리게이트 추가
        roomDelegate.onAudioTrackPublished = { track in
            print("Audio track published")
            Task { @MainActor in
                // 오디오 트랙 설정
                try await track.start()
            }
        }
        
        roomCtx.room.add(delegate: roomDelegate)
        print("Room delegate setup completed")
    }
    
    private func setupGameTimer() {
        viewModel.onGameStart = {
            isGameTimerRunning = true
            gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                if remainingTime > 0 {
                    remainingTime -= 1
                } else {
                    endGame()
                }
            }
        }
    }
    
    private func endGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        isGameTimerRunning = false
        
        Task {
            // 게임 종료 처리
            await cleanupSession()
            
            // 결과 화면으로 이동
            await MainActor.run {
                navigateToResult = true
            }
        }
    }
    
    // MARK: - Actions
    private func startButtonAction() {
        Task {
            print("Game start button pressed")
            
            // 1. LiveKit 연결 및 카메라 설정 확인
            guard isConnected else {
                errorMessage = "LiveKit 연결이 필요합니다."
                showErrorAlert = true
                return
            }
            
            // 실제 디바이스에서 카메라 설정 확인
            if !viewModel.isTestMode {
                guard !roomCtx.room.localParticipant.videoTracks.isEmpty else {
                    errorMessage = "카메라 설정이 필요합니다."
                    showErrorAlert = true
                    return
                }
            }
            
            // 상대방 연결 확인
            guard !roomCtx.room.remoteParticipants.isEmpty else {
                errorMessage = "상대방과의 연결이 필요합니다."
                showErrorAlert = true
                return
            }
            
            print("LiveKit connection verified, proceeding to WebSocket connection")
            
            // 2. WebSocket 연결
            let wsConnected = await viewModel.connectWebSocket(channelId: channelId)
            
            guard wsConnected else {
                errorMessage = "WebSocket 연결에 실패했습니다. 다시 시도해주세요."
                showErrorAlert = true
                return
            }
            
            // 3. API 호출
            await punchBagTestModel.postPunchgameStart(channelId: channelId)
            
            if punchBagTestModel.response.status == 200 {
                print("API call successful, sending READY status")
                // 4. READY 상태 전송
                await viewModel.sendReadyStatus()
                
                // 5. 상대방의 READY 상태 확인은 WebSocket 메시지 수신에서 처리됨
                if !viewModel.isOpponentReady {
                    print("Waiting for opponent to be ready...")
                }
            } else {
                errorMessage = "게임 시작에 실패했습니다. 다시 시도해주세요."
                showErrorAlert = true
            }
        }
    }
    
    // MARK: - Stats Views
    private var opponentStatsView: some View {
        HStack(spacing: 15) {
            StatItem(
                icon: "hand.raised.fill",
                value: "0",
                label: "펀치",
                color: mainRed
            )
        }
    }
    
    private var myStatsView: some View {
        HStack(spacing: 15) {
            StatItem(
                icon: "hand.raised.fill",
                value: "\(gameManager.punchCount)",
                label: "펀치",
                color: mainRed
            )
            
            StatItem(
                icon: "heart.fill",
                value: "\(Int(healthKitManager.heartRate))",
                label: "BPM",
                color: .red
            )
            
            StatItem(
                icon: "flame.fill",
                value: "\(Int(healthKitManager.activeCalories))",
                label: "kcal",
                color: .orange
            )
        }
    }
    
    private var dummyVideoView: some View {
        ZStack {
            Color.black
                .overlay(
                    VStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Test Mode")
                            .foregroundColor(.gray)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Connection Methods
    private func connectToRoom() async throws {
        let livekitUrl = "wss://openvidufightclubsubdomain.click"
        let roomName = "punchGame"
        let participantName = "player_\(Int.random(in: 1000...9999))"
        let applicationServerUrl = "http://43.201.27.173:6080"
        
        let token = try await httpService.getToken(
            applicationServerUrl: applicationServerUrl,
            roomName: roomName,
            participantName: participantName)
        
        guard !token.isEmpty else {
            throw NSError(domain: "LiveKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "토큰이 비어있습니다"])
        }
        
        roomCtx.token = token
        roomCtx.livekitUrl = livekitUrl
        roomCtx.name = roomName
        
        _ = try await roomCtx.connect()
    }
}
