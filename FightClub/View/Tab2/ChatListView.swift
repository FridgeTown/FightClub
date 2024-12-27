//
//  ChatListView.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI

struct ChatListView: View {
    let activeChats: [Chat]
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(activeChats) { chat in
                HStack {
                    VStack(alignment: .leading) {
                        Text(chat.userName)
                                .font(.headline)
                        Text(chat.lastMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("10:30 AM")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.background)
                .cornerRadius(8)
                .shadow(radius: 2)
            }
        }
        .padding(.horizontal)
    }
}
#Preview {
//    ChatListView()
}
