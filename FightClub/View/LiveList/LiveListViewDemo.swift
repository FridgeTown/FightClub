//
//  LiveListView.swift
//  FightClub
//
//  Created by Edward Lee on 1/2/25.
//

import SwiftUI
import Foundation
import LiveKit
import KeychainAccess

struct LiveListViewDemo: View {
    @StateObject private var roomContext: RoomContext
    @StateObject private var appContext: AppContext
    @State private var isStreamingViewActive = false
    @StateObject private var notificationService = NotificationService.shared
    
    init() {
        let preferences = Preferences()
        let keychain = Keychain(service: "com.fightclub.app")
        let store = ValueStore(store: keychain, 
                             key: "preferences",
                             default: preferences)
        _roomContext = StateObject(wrappedValue: RoomContext(store: store))
        _appContext = StateObject(wrappedValue: AppContext(store: store))
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 20) {
                    Button("로그아웃") {
                        try? TokenManager.shared.clearAllTokens()
                    }
                    Button("방송 송출 하기 ") {
                        isStreamingViewActive = true
                    }
                    Button(UserDataManager.shared.nickname ?? "알수없음") {
                        
                    }
                    
                    // 알림 테스트 버튼 추가
                    Button("알림 테스트") {
                        let testEvent = NotificationEvent(
                            type: "MATCH_REQUEST",
                            message: "케이투님이 스파링 요청을 보냈습니다!",
                            data: NotificationData(matchId: 123, channelId: nil)
                        )
                        notificationService.showInAppNotification(testEvent)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .navigationTitle("실시간 매치")
                .navigationBarTitleDisplayMode(.large)
            }
            
            // 알림 오버레이 추가
            NotificationOverlay()
        }
    }
}

#Preview {
    LiveListViewDemo()
}
