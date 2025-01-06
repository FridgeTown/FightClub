import Foundation
import Combine

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

class NotificationService: ObservableObject {
    // MARK: - Properties
    static let shared = NotificationService()
    
    @Published private(set) var isConnected = false
    private var urlSession: URLSession?
    private var eventTask: URLSessionDataTask?
    private let notificationSubject = PassthroughSubject<NotificationEvent, Never>()
    private var buffer = ""
    
    var notificationPublisher: AnyPublisher<NotificationEvent, Never> {
        notificationSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    private init() {
        setupURLSession()
    }
    
    // MARK: - Public Methods
    func startService() {
        guard eventTask == nil else { return }
        connectToSSE()
    }
    
    func stopService() {
        eventTask?.cancel()
        eventTask = nil
        isConnected = false
    }
    
    // MARK: - Private Methods
    private func setupURLSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(INT_MAX)
        configuration.timeoutIntervalForResource = TimeInterval(INT_MAX)
        urlSession = URLSession(configuration: configuration)
    }
    
    private func connectToSSE() {
        guard let userId = UserDataManager.shared.getUserData()?.id.toString() else {
            print("Missing user ID")
            return
        }
        
        let urlString = "http://3.34.46.87:8080/notification/subscribe/notification/subscribe"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = UserDataManager.shared.getUserData()?.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        eventTask = urlSession?.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("SSE Error: \(error.localizedDescription)")
                self?.handleConnectionError()
                return
            }
            
            if let data = data,
               let text = String(data: data, encoding: .utf8) {
                self?.processSSEData(text)
            }
        }
        
        eventTask?.resume()
        isConnected = true
    }
    
    private func processSSEData(_ text: String) {
        buffer += text
        
        while let eventEnd = buffer.range(of: "\n\n") {
                let eventString = buffer[..<eventEnd.lowerBound]
                buffer = String(buffer[eventEnd.upperBound...])
            
            var event: String?
            var data: String?
            
            let lines = eventString.components(separatedBy: "\n")
            for line in lines {
                if line.hasPrefix("event:") {
                    event = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                }
            }
            
            if let event = event, let data = data {
                handleNotification(event: event, data: data)
            }
        }
    }
    
    private func handleNotification(event: String, data: String) {
        guard let jsonData = data.data(using: .utf8) else {
            print("Failed to convert string to data")
            return
        }
        
        do {
            let notification = try JSONDecoder().decode(NotificationEvent.self, from: jsonData)
            DispatchQueue.main.async { [weak self] in
                self?.notificationSubject.send(notification)
            }
        } catch {
            print("Failed to decode notification: \(error)")
        }
    }
    
    private func handleConnectionError() {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.reconnect()
        }
    }
    
    private func reconnect() {
        stopService()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.startService()
        }
    }
} 
