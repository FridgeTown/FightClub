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
        NavigationView {
            VStack {
                Button("로그아웃") {
                    try? TokenManager.shared.clearAllTokens()
                }
                Button("방송 송출 하기 ") {
                    isStreamingViewActive = true
                }
                .fullScreenCover(isPresented: $isStreamingViewActive) {
                    StreamingView()
                        .environmentObject(roomContext)
                        .environmentObject(appContext)
                }
                Button("방송 시청 하기 ") {
                    
                }
            }
            .navigationTitle("실시간 매치")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    LiveListViewDemo()
}
