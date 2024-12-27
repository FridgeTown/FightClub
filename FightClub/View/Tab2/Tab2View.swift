//
//  Tab2View.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI

struct Tab2View: View {
    @State private var matchRequests: [MatchRequest] = [
        MatchRequest(id: 1, nickname: "Boxer1", weight: 70, height: 175),
        MatchRequest(id: 2, nickname: "Boxer2", weight: 65, height: 180),
//        MatchRequest(id: 3, nickname: "Boxer3", weight: 75, height: 170),
//        MatchRequest(id: 4, nickname: "Boxer4", weight: 68, height: 178)
    ]
    
    @State private var activeChats: [Chat] = [
        Chat(id: 1, userName: "Boxer5", lastMessage: "Let's spar!"),
        Chat(id: 2, userName: "Boxer6", lastMessage: "Ready for a match?"),
        Chat(id: 3, userName: "Boxer7", lastMessage: "Good match!")
    ]
    
    var body: some View {
        ScrollView {
                    VStack(spacing: 16) {
                        MatchRequestView(matchRequests: Array(matchRequests.prefix(3))) // 최대 3개만 표시
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        
                        // Divider
                        Divider()
                            .padding(.horizontal)
                        
                        // ChatListView
                        ChatListView(activeChats: activeChats)
                    }
                    .padding(.vertical)
                }
                .background(Color(.systemGroupedBackground))
            }
}

// MARK: - Models
struct MatchRequest: Identifiable {
    let id: Int
    let nickname: String
    let weight: Int
    let height: Int
}

struct Chat: Identifiable {
    let id: Int
    let userName: String
    let lastMessage: String
}

#Preview {
    Tab2View()
}
