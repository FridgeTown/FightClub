//
//  ChatListView.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI
import TalkPlus

struct ChatRowView: View {
    let channel: ChatChannel
    
    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: channel.profileImageUrl ?? "")) { phase in
                switch phase {
                case .empty:
                    Image(systemName: "profile_placeholder")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .foregroundColor(.gray.opacity(0.3))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                case .failure:
                    Image(systemName: "profile_placeholder")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .foregroundColor(.gray.opacity(0.3))
                @unknown default:
                    EmptyView()
                }
            }
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.mainRed.opacity(0.7), Color.mainRed],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(channel.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack {
                    Text(channel.lastMessage)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .id("\(channel.lastMessage)_\(channel.lastMessageTime)")
            }
            
            Spacer()
            
            if channel.unreadCount > 0 {
                HStack {
                    Text("\(channel.unreadCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.mainRed)
                        .clipShape(Circle())
                        .shadow(color: Color.mainRed.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .id(channel.unreadCount)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .contentShape(Rectangle())
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color.mainRed.opacity(0.3))
                .shadow(color: Color.mainRed.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                Text("아직 매칭된 스파링 파트너가 없습니다")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("새로운 파트너를 찾아보세요")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
