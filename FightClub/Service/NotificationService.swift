import Foundation
import Combine
import Network
import UIKit
import SwiftUI

enum NotificationType: String {
    case matchRequest = "새로운 스파링 요청"
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
        case .matchRequest: return "figure.wave.circle.fill"
        case .newMessage: return "message.fill"
        case .unknown: return "bell.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .matchRequest: return .red
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
    @State private var offset: CGFloat = -100
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }
    
    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.gray.opacity(0.3),
                Color.black.opacity(0.7)
            ]
        } else {
            return [
                Color.white.opacity(0.9),
                Color.white.opacity(0.7)
            ]
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 아이콘 컨테이너
            Circle()
                .fill(event.notificationType.color.opacity(colorScheme == .dark ? 0.2 : 0.15))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: event.notificationType.icon)
                        .font(.system(size: 24))
                        .foregroundColor(event.notificationType.color)
                )
            
            // 텍스트 컨테이너
            VStack(alignment: .leading, spacing: 4) {
                Text(event.notificationType.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                
                Text(event.message)
                    .font(.system(size: 14))
                    .foregroundColor(secondaryTextColor)
                    .lineLimit(2)
            }
            .padding(.trailing, 8)
            
            Spacer()
            
            // 닫기 버튼
            Button(action: {
                withAnimation(.spring()) {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                backgroundColor
                    .opacity(0.98)
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 0.5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
            radius: colorScheme == .dark ? 15 : 20,
            x: 0,
            y: 10
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            (colorScheme == .dark ? Color.white : Color.white).opacity(0.3),
                            (colorScheme == .dark ? Color.white : Color.white).opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .offset(y: offset)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                offset = 0
            }
        }
        .onTapGesture {
            withAnimation(.spring()) {
                isPresented = false
            }
        }
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
        
        guard let url = URL(string: "http://43.200.49.201:8080/notification/subscribe") else {
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
        print("processSSEDData", text)
        
        if text.contains("습니다") {
            let event = NotificationEvent(
                type: "MATCH_REQUEST",
                message: text,
                data: NotificationData(matchId: nil, channelId: nil)
            )
            
            DispatchQueue.main.async { [weak self] in
                self?.showInAppNotification(event)
                self?.notificationSubject.send(event)
            }
        }
    }
    
    func showInAppNotification(_ event: NotificationEvent) {
        currentNotification = event
        showNotification = true
        
        // 3초 후에 알림 숨기기
        hideNotificationTimer?.invalidate()
        hideNotificationTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation {
                    self?.showNotification = false
                }
            }
        }
    }
}
