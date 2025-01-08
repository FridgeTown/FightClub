import SwiftUI
import LiveKit
import KeychainAccess

struct LiveWatchView: View {
    let live: LiveListModel
    @StateObject private var roomCtx: RoomContext = {
        let preferences = Preferences()
        let keychain = Keychain(service: "com.fightclub.app")
        let store = ValueStore(store: keychain, 
                             key: "preferences",
                             default: preferences)
        return RoomContext(store: store)
    }()
    @State private var isLoading = false
    @State private var connectionError: String?
    
    var httpService = HTTPClient()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 배경
                Color.black.ignoresSafeArea()
                
                // 메인 컨텐츠
                mainContentView
                
                // 상단 정보
                VStack {
                    matchInfoOverlay
                    Spacer()
                }
                
                // 로딩 오버레이
                if isLoading {
                    loadingOverlay
                }
            }
        }
        .navigationTitle("라이브 시청")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { connectToRoom() }
        .onDisappear {
            Task { await roomCtx.disconnect() }
        }
    }
    
    // MARK: - 컴포넌트 뷰
    
    private var mainContentView: some View {
        Group {
            if let streamer = roomCtx.room.remoteParticipants.values.first,  // 첫 번째 참가자(스트리머)
               let publication = streamer.videoTracks.first,  // �트리머의 첫 번째 비디오 트랙
               let track = publication.track as? VideoTrack {
                ZStack {
                    SwiftUIVideoView(track, layoutMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 비디오 컨트롤 오버레이
                    videoControlsOverlay
                }
            } else {
                waitingView
            }
        }
    }
    
    private var matchInfoOverlay: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(live.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.gray)
                    Text(live.place)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.7))
            )
            
            Spacer()
            
            // LIVE 표시
            Text("LIVE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red)
                .clipShape(Capsule())
                .padding()
        }
        .padding(.top, 44) // 안전 영역 고려
    }
    
    private var videoControlsOverlay: some View {
        VStack {
            Spacer()
            HStack {
                // 여기에 필요한 컨트롤 버튼들 추가 (음소거, 전체화면 등)
                Button(action: {
                    // 음소거 토글
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.white)
                        .padding()
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
                
                Spacer()
                
                Button(action: {
                    // 전체화면 토글
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .foregroundColor(.white)
                        .padding()
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
            }
            .padding()
        }
    }
    
    private var waitingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.fill")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            if let error = connectionError {
                Text(error)
                    .font(.headline)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("다시 시도") {
                    connectToRoom()
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            } else {
                Text("스트리밍 연결 대기 중...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
    
    private var loadingOverlay: some View {
        Color.black.opacity(0.7)
            .ignoresSafeArea()
            .overlay(
                ProgressView("스트리밍 연결 중...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .foregroundColor(.white)
            )
    }
    
    // MARK: - 네트워크 연결
    
    private func connectToRoom() {
        Task {
            isLoading = true
            connectionError = nil
            
            let livekitUrl = "wss://openvidufightclubsubdomain.click"
            let roomName = "myRoom"
            let participantName = "viewer_\(Int.random(in: 1000...9999))"
            let applicationServerUrl = "http://43.201.27.173:6080"
            
            do {
                print("Connecting to room: \(roomName) as \(participantName)")
                
                // 1. 토큰 획득
                let token = try await httpService.getToken(
                    applicationServerUrl: applicationServerUrl,
                    roomName: roomName,
                    participantName: participantName)
                
                guard !token.isEmpty else {
                    connectionError = "토큰을 받아올 수 없습니다."
                    isLoading = false
                    return
                }
                
                print("Token received successfully")
                
                // 2. Room 설정
                roomCtx.token = token
                roomCtx.livekitUrl = livekitUrl
                roomCtx.name = roomName
                
                // 3. Room 연결
                try await roomCtx.connect()
                
                print("Room connected successfully")
                
                // 4. 스트리머 정보 출력
                if let streamer = roomCtx.room.remoteParticipants.values.first {
                    print("Streamer found - Identity: \(streamer.identity)")
                    print("Video tracks count: \(streamer.videoTracks.count)")
                    
                    for track in streamer.videoTracks {
                        print("Track info - Name: \(track.name), Kind: \(track.kind), Muted: \(track.isMuted)")
                    }
                } else {
                    print("No streamer found in the room")
                    connectionError = "스트리머를 찾을 수 없습니다."
                }
                
            } catch {
                print("Connection error: \(error)")
                connectionError = error.localizedDescription
            }
            
            isLoading = false
        }
    }
}
