//
//  ChatListView.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI

struct ChatListView: View {
    let activeChats: [Chat]
    @State private var selectedChat: Chat?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("매칭된 스파링 파트너")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.mainRed)
                .padding(.horizontal)
            
            if activeChats.isEmpty {
                EmptyStateView()
            } else {
                ForEach(activeChats) { chat in
                    ChatRowView(chat: chat)
                        .onTapGesture {
                            selectedChat = chat
                        }
                }
            }
        }
        .sheet(item: $selectedChat) { chat in
            ChatRoomView(chat: chat)
        }
    }
}

struct ChatRowView: View {
    let chat: Chat
    
    var body: some View {
        HStack(spacing: 16) {
            // 프로필 이미지
            Image("profile_placeholder")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.mainRed.opacity(0.2), lineWidth: 2)
                )
            
            // 채팅 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.userName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 시간 표시 (나중에 추가 예정)
            // Text(chat.lastMessageTime)
            //     .font(.caption)
            //     .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.mainRed.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.circle")
                .font(.system(size: 60))
                .foregroundColor(Color.mainRed.opacity(0.3))
            
            Text("아직 매칭된 스파링 파트너가 없습니다")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview
struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        ChatListView(activeChats: [
            Chat(id: 1, userName: "Boxer Kim", lastMessage: "오늘 스파링 어떠셨나요?"),
            Chat(id: 2, userName: "Fighter Lee", lastMessage: "다음 스파링 일정 잡아요!"),
            Chat(id: 3, userName: "Champion Park", lastMessage: "좋은 경기였습니다!")
        ])
    }
}
