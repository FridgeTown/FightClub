import Foundation
import SwiftUI
import Combine
import LiveKit
import WatchConnectivity

class PunchBagTestViewModel: NSObject, ObservableObject, WCSessionDelegate {
    // MARK: - Published Properties
    @Published var isWebSocketConnected = false
    @Published var isOpponentConnected = false
    @Published var isReady = false
    @Published var isOpponentReady = false
    @Published var isReadyToStart = false
    @Published var showCountdown = false
    @Published var countdownValue = 3
    @Published var gameStarted = false
    @Published var isTestMode = false
    
    // MARK: - Game Data
    @Published var currentPunchMagnitude: Double = 0.0
    @Published var maxPunchMagnitude: Double = 0.0
    @Published var punchCount: Int = 0
    @Published var averagePunchMagnitude: Double = 0.0
    @Published var currentHeartRate: Double = 0.0
    @Published var gameResult: GameResult?
    
    private var totalPunchMagnitude: Double = 0.0
    private var punchDataBuffer: [(magnitude: Double, timestamp: Date)] = []
    
    // MARK: - Communication
    var room: Room?
    private var webSocketTask: URLSessionWebSocketTask?
    private var wcSession: WCSession?
    var onGameStart: (() -> Void)?
    
    private var countdownTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupWatchConnection()
    }
    
    private func setupWatchConnection() {
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }
    }
    
    // MARK: - Watch Connectivity Delegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("WCSession activation completed: \(activationState.rawValue)")
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async { [weak self] in
            if let magnitude = message["punchMagnitude"] as? Double {
                self?.processPunchData(magnitude: magnitude)
            }
            if let heartRate = message["heartRate"] as? Double {
                self?.currentHeartRate = heartRate
            }
        }
    }
    
    // MARK: - Game Logic
    private func processPunchData(magnitude: Double) {
        guard gameStarted else { return }
        
        currentPunchMagnitude = magnitude
        totalPunchMagnitude += magnitude
        punchCount += 1
        
        // 최대 펀치 강도 업데이트
        if magnitude > maxPunchMagnitude {
            maxPunchMagnitude = magnitude
        }
        
        // 평균 펀치 강도 계산
        averagePunchMagnitude = totalPunchMagnitude / Double(punchCount)
        
        // 펀치 데이터 버퍼에 저장
        punchDataBuffer.append((magnitude: magnitude, timestamp: Date()))
        
        // WebSocket을 통해 상대방에게 데이터 전송
        let punchData: [String: Any] = [
            "type": "PUNCH_DATA",
            "magnitude": magnitude,
            "heartRate": currentHeartRate
        ]
        sendGameData(punchData)
    }
    
    private func sendGameData(_ data: [String: Any]) {
        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("Sending WebSocket message: \(jsonString)")
            webSocketTask?.send(.string(jsonString)) { error in
                if let error = error {
                    print("Failed to send game data: \(error)")
                } else {
                    print("Successfully sent message")
                }
            }
        }
    }
    
    // MARK: - Game Flow
    func startCountdown() async {
        await MainActor.run {
            showCountdown = true
            countdownValue = 3
            
            // 게임 데이터 초기화
            currentPunchMagnitude = 0.0
            maxPunchMagnitude = 0.0
            punchCount = 0
            averagePunchMagnitude = 0.0
            totalPunchMagnitude = 0.0
            punchDataBuffer.removeAll()
        }
        
        // 3초 카운트다운
        for _ in 1...3 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                countdownValue -= 1
            }
        }
        
        await MainActor.run {
            showCountdown = false
            gameStarted = true
            onGameStart?()  // 게임 시작 콜백 호출
        }
    }
    
    func endGame() {
        gameStarted = false
        
        // 게임 결과 분석
        let gameStats = GameStats(
            maxPunchMagnitude: maxPunchMagnitude,
            averagePunchMagnitude: averagePunchMagnitude,
            punchCount: punchCount,
            averageHeartRate: currentHeartRate
        )
        
        // 결과 전송
        let resultData: [String: Any] = [
            "type": "GAME_RESULT",
            "stats": [
                "maxPunchMagnitude": gameStats.maxPunchMagnitude,
                "averagePunchMagnitude": gameStats.averagePunchMagnitude,
                "punchCount": gameStats.punchCount,
                "averageHeartRate": gameStats.averageHeartRate
            ]
        ]
        sendGameData(resultData)
    }
    
    // MARK: - LiveKit Methods
    func checkReadyState(in room: Room) {
        isReadyToStart = !room.remoteParticipants.isEmpty
    }
    
    func participantDidJoin(_ participant: RemoteParticipant) {
        isOpponentConnected = true
        checkGameStart()
    }
    
    func participantDidLeave(_ participant: RemoteParticipant) {
        isOpponentConnected = false
        checkGameStart()
    }
    
    func checkGameStart() {
        isReadyToStart = isOpponentConnected
    }
    
    func connectWebSocket(channelId: String) async -> Bool {
        let url = URL(string: "ws://43.200.49.201:6080/channel/\(channelId)/")!
        let request = URLRequest(url: url)
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        
        print("Attempting to connect to WebSocket URL: \(url.absoluteString)")
        
        // 연결 시도
        webSocketTask?.resume()
        
        // 연결 상태 확인을 위한 ping 전송
        do {
            // 연결이 설정될 때까지 잠시 대기
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            try await webSocketTask?.sendPing(pongReceiveHandler: { error in
                if let error = error {
                    print("Ping failed: \(error)")
                } else {
                    print("Ping succeeded")
                }
            })
            
            await MainActor.run {
                isWebSocketConnected = true
                print("WebSocket connected successfully")
            }
            
            receiveMessage()
            return true
        } catch {
            print("WebSocket connection failed: \(error)")
            await MainActor.run {
                isWebSocketConnected = false
            }
            return false
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("Received message: \(text)")
                    // JSON 파싱 시도
                    if let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        Task { @MainActor in
                            if let type = json["type"] as? String {
                                print("Processing message type: \(type)")
                                switch type {
                                case "READY":
                                    print("Received READY from opponent")
                                    self?.isOpponentReady = true
                                    self?.checkAndStartCountdown()
                                case "START":
                                    self?.gameStarted = true
                                case "PUNCH_DATA":
                                    if let magnitude = json["magnitude"] as? Double,
                                       let heartRate = json["heartRate"] as? Double {
                                        print("Opponent punch: magnitude=\(magnitude), heartRate=\(heartRate)")
                                    }
                                default:
                                    print("Unknown message type: \(type)")
                                }
                            }
                        }
                    }
                case .data(let data):
                    print("Received binary data: \(data)")
                @unknown default:
                    break
                }
                // 다음 메시지 수신을 위해 재귀 호출
                self?.receiveMessage()
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                Task { @MainActor in
                    self?.isWebSocketConnected = false
                }
                // 연결 실패 시 재연결 시도
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    self?.receiveMessage()
                }
            }
        }
    }
    
    private func checkAndStartCountdown() {
        print("Checking countdown conditions - isReady: \(isReady), isOpponentReady: \(isOpponentReady), gameStarted: \(gameStarted), showCountdown: \(showCountdown)")
        
        Task { @MainActor in
            if isReady && isOpponentReady && !gameStarted && !showCountdown {
                print("Both players are ready, starting countdown")
                await startCountdown()
            }
        }
    }
    
    func sendReadyStatus() async {
        await MainActor.run {
            isReady = true
            print("Set local ready status to true")
        }
        
        // 임시: 바로 카운트다운 시작
        print("Starting countdown immediately (temporary)")
        await startCountdown()
        
        // WebSocket을 통한 READY 메시지 전송 (나중을 위해 유지)
        let readyData: [String: Any] = [
            "type": "READY"
        ]
        sendGameData(readyData)
    }
    
    func disconnectAll() {
        webSocketTask?.cancel()
        webSocketTask = nil
        isWebSocketConnected = false
        isOpponentConnected = false
        isReady = false
        isOpponentReady = false
        isReadyToStart = false
        showCountdown = false
        gameStarted = false
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    // MARK: - Existing Methods...
    // (이전 메서드들은 그대로 유지)
}

// MARK: - Supporting Types
struct GameStats {
    let maxPunchMagnitude: Double
    let averagePunchMagnitude: Double
    let punchCount: Int
    let averageHeartRate: Double
}

enum GameResult {
    case win
    case lose
    case draw
} 
