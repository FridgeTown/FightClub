import Foundation
import Combine
import Network
import UIKit
import SwiftUI

enum NotificationType: String {
    case matchRequest = "MATCH_REQUEST"
    case newMessage = "NEW_MESSAGE"
    case unknown
    
    init(rawValue: String) {
        switch rawValue {
        case "MATCH_REQUEST": self = .matchRequest
        case "NEW_MESSAGE": self = .newMessage
        default: self = .unknown
        }
    }
    
    var icon: String {
        switch self {
        case .matchRequest: return "person.2.fill"
        case .newMessage: return "message.fill"
        case .unknown: return "bell.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .matchRequest: return .blue
        case .newMessage: return .green
        case .unknown: return .gray
        }
    }
}

struct NotificationEvent: Codable {
    let type: String
    let message: String
    let data: NotificationData
    
    var notificationType: NotificationType {
        NotificationType(rawValue: type)
    }
}

struct NotificationData: Codable {
    let matchId: Int?
    let channelId: String?
}

// 알림 배너 뷰
struct NotificationBanner: View {
    let event: NotificationEvent
    @Binding var isPresented: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.notificationType.icon)
                .font(.system(size: 24))
                .foregroundColor(event.notificationType.color)
            
            VStack(alignment: .center, spacing: 4) {
                Text(event.notificationType.rawValue)
                    .font(.system(size: 16, weight: .bold))
                Text(event.message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            
            Button(action: {
                withAnimation {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .frame(width: 300)  // 고정된 너비 설정
        .background(.white)
        .cornerRadius(15)
        .shadow(color: Color.mainRed.opacity(0.2), radius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.mainRed.opacity(0.1), lineWidth: 1)
        )
    }
}

class NotificationService: NSObject, ObservableObject, URLSessionDataDelegate {
    static let shared = NotificationService()
    
    @Published private(set) var isConnected = false
    @Published var currentNotification: NotificationEvent?
    @Published var showNotification = false
    
    private var urlSession: URLSession!
    private var eventTask: URLSessionDataTask?
    private let notificationSubject = PassthroughSubject<NotificationEvent, Never>()
    private var buffer = ""
    private var isReconnecting = false
    private var retryTimer: Timer?
    private var connectionCheckTimer: Timer?
    private var lastDataReceived: Date?
    private var keepAliveTimer: Timer?
    private var hideNotificationTimer: Timer?
    
    // 네트워크 모니터링
    private var networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    private var currentPath: NWPath?
    
    var notificationPublisher: AnyPublisher<NotificationEvent, Never> {
        notificationSubject.eraseToAnyPublisher()
    }
    
    private override init() {
        super.init()
        setupURLSession()
        setupNetworkMonitoring()
        startConnectionCheck()
        startKeepAlive()
    }
    
    deinit {
        stopService()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.currentPath = path
            
            DispatchQueue.main.async {
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied
                print("Network status changed - Available: \(self.isNetworkAvailable)")
                
                if wasAvailable != self.isNetworkAvailable {
                    if self.isNetworkAvailable {
                        if !self.isConnected {
                            print("Network became available, attempting to connect")
                            self.reconnectWithDelay()
                        }
                    } else {
                        print("Network became unavailable")
                        self.cleanupExistingConnection()
                    }
                }
            }
        }
        
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }
    
    private func setupURLSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60  // 타임아웃 시간 증가
        configuration.timeoutIntervalForResource = 3600  // 1시간으로 증가
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.shouldUseExtendedBackgroundIdleMode = true
        
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }
    
    private func startKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkKeepAlive()
        }
    }
    
    private func checkKeepAlive() {
        guard let lastReceived = lastDataReceived else {
            if isConnected {
                print("No data received recently, reconnecting...")
                handleConnectionError()
            }
            return
        }
        
        let timeSinceLastData = Date().timeIntervalSince(lastReceived)
        if timeSinceLastData > 45 {  // 45초 동안 데이터가 없으면 재연결
            print("No data received for \(Int(timeSinceLastData)) seconds, reconnecting...")
            handleConnectionError()
        }
    }
    
    private func startConnectionCheck() {
        connectionCheckTimer?.invalidate()
        connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.checkConnection()
        }
    }
    
    private func checkConnection() {
        guard isNetworkAvailable else { return }
        
        if !isConnected && !isReconnecting {
            print("Connection check failed, attempting to reconnect")
            reconnectWithDelay()
        }
    }
    
    private func reconnectWithDelay() {
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.startService()
        }
    }
    
    func startService() {
        print("Starting SSE service...")
        guard eventTask == nil, !isReconnecting else {
            print("Connection already exists or reconnecting")
            return
        }
        
        guard isNetworkAvailable else {
            print("Network not available")
            return
        }
        
        connectToSSE()
    }
    
    func stopService() {
        print("Stopping SSE service...")
        retryTimer?.invalidate()
        retryTimer = nil
        connectionCheckTimer?.invalidate()
        connectionCheckTimer = nil
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        cleanupExistingConnection()
        networkMonitor.cancel()
    }
    
    private func cleanupExistingConnection() {
        print("Cleaning up existing connection...")
        eventTask?.cancel()
        eventTask = nil
        lastDataReceived = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            print("Connection status set to false")
        }
        
        buffer = ""
    }
    
    private func connectToSSE() {
        guard let token = try? TokenManager.shared.getAccessToken() else {
            print("No auth token available")
            return
        }
        
        guard let url = URL(string: "http://3.34.46.87:8080/notification/subscribe") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 60
        
        cleanupExistingConnection()
        
        print("Attempting to connect to SSE...")
        eventTask = urlSession.dataTask(with: request)
        eventTask?.resume()
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession,
                   dataTask: URLSessionDataTask,
                   didReceive response: URLResponse,
                   completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Received HTTP response with status code: \(httpResponse.statusCode)")
            if httpResponse.statusCode == 200 {
                print("SSE connection established")
                DispatchQueue.main.async {
                    self.isConnected = true
                    self.reconnectAttempts = 0
                    print("Connection status set to true")
                }
                completionHandler(.allow)
            } else {
                print("Invalid HTTP response: \(httpResponse.statusCode)")
                completionHandler(.cancel)
                handleConnectionError()
            }
        }
    }
    
    func urlSession(_ session: URLSession,
                   dataTask: URLSessionDataTask,
                   didReceive data: Data) {
        lastDataReceived = Date()
        if let text = String(data: data, encoding: .utf8) {
            processSSEData(text)
        }
    }
    
    func urlSession(_ session: URLSession,
                   task: URLSessionTask,
                   didCompleteWithError error: Error?) {
        if let error = error as NSError? {
            if error.code != NSURLErrorCancelled {
                print("SSE connection error: \(error.localizedDescription)")
                handleConnectionError()
            }
        }
        print("URLSession task completed")
    }
    
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
    private func handleConnectionError() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isConnected = false
            print("Connection error occurred, status set to false")
            
            guard self.isNetworkAvailable else {
                print("Network not available, waiting for network")
                return
            }
            
            if self.reconnectAttempts < self.maxReconnectAttempts {
                self.reconnectAttempts += 1
                self.isReconnecting = true
                
                let delay = Double(min(32, 1 << self.reconnectAttempts))
                print("Reconnecting in \(delay) seconds (attempt \(self.reconnectAttempts))")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.isReconnecting = false
                    self.connectToSSE()
                }
            } else {
                print("Max reconnection attempts reached")
                self.reconnectAttempts = 0
                self.cleanupExistingConnection()
            }
        }
    }
    
    private func processSSEData(_ text: String) {
        buffer += text
        
        let maxBufferSize = 1024 * 1024 // 1MB
        if buffer.count > maxBufferSize {
            buffer = String(buffer.suffix(maxBufferSize / 2))
        }
        
        let lines = buffer.components(separatedBy: "\n")
        buffer = lines.last ?? ""
        
        var currentEvent = ""
        var currentData = ""
        
        for line in lines.dropLast() {
            if line.hasPrefix("event:") {
                currentEvent = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                currentData = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                
                
                
                // 이벤트와 데이터가 모두 있을 때 처리
                if currentEvent == "notification" || !currentData.isEmpty {
                    print("SSE Notification received:", currentData)
                    
                    // 알림 이벤트 생성
                    let event = NotificationEvent(
                        type: "MATCH_REQUEST",
                        message: currentData,
                        data: NotificationData(matchId: nil, channelId: nil)
                    )
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.showInAppNotification(event)
                        self?.notificationSubject.send(event)
                    }
                    
                    // 처리 후 초기화
                    currentEvent = ""
                    currentData = ""
                }
            }
        }
    }
    
    func showInAppNotification(_ event: NotificationEvent) {
        currentNotification = event
        showNotification = true
        
        // 3초 후에 알림 숨기기
        hideNotificationTimer?.invalidate()
        hideNotificationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation {
                    self?.showNotification = false
                }
            }
        }
    }
}
