//
//  MainTabView.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI
import Combine

struct MainTabView: View {
    // MARK: - Properties
    @State private var selectedTab = 0
    @StateObject private var notificationHandler = NotificationHandler()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("홈", systemImage: "flame.fill")
                }
                .tag(0)
            
            Tab2View()
                .tabItem {
                    Label("채팅", systemImage: "message.fill")
                }
                .tag(1)
            
            profileSection
                .tag(2)
                
            recordSection
                .tag(3)
        }
        .tint(.red)
        .onAppear {
            NotificationService.shared.startService()
        }
        .onDisappear {
            NotificationService.shared.stopService()
        }
        .environmentObject(notificationHandler)
    }
    
    // MARK: - Views
    private var profileSection: some View {
        LiveListView()
        .tabItem {
            Label("LIVE", systemImage: "antenna.radiowaves.left.and.right")
        }
    }
    
    private var recordSection: some View {
        RecordListView()
            .tabItem {
                Label("기록", systemImage: "figure.boxing.circle.fill")
            }
    }
}

class NotificationHandler: ObservableObject {
    // MARK: - Properties
    @Published private(set) var lastNotification: NotificationEvent?
    @Published private(set) var isConnected = false
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupNotificationSubscription()
        setupConnectionMonitoring()
    }
    
    // MARK: - Private Methods
    private func setupNotificationSubscription() {
        NotificationService.shared.notificationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleNotification(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleNotification(_ event: NotificationEvent) {
        lastNotification = event
        
        switch event.notificationType {
        case .matchRequest:
            handleMatchRequest(event)
        case .newMessage:
            handleNewMessage(event)
        case .unknown:
            print("Unknown notification type: \(event.type)")
        }
    }
    
    private func handleMatchRequest(_ event: NotificationEvent) {
        print("New match request received: \(event.message)")
        // TODO: 매치 요청 처리 로직 구현
    }
    
    private func handleNewMessage(_ event: NotificationEvent) {
        print("New message received: \(event.message)")
        // TODO: 새 메시지 처리 로직 구현
    }
    
    private func setupConnectionMonitoring() {
        NotificationService.shared.$isConnected
            .sink { [weak self] connected in
                print("SSE Connection status: \(connected)")
                self?.isConnected = connected
            }
            .store(in: &cancellables)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
