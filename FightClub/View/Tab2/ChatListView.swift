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
                case .empty, .failure:
                    Image("profile_placeholder")
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
                
                Text(channel.lastMessage)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if channel.unreadCount > 0 {
                Text("\(channel.unreadCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.mainRed)
                    .clipShape(Circle())
                    .shadow(color: Color.mainRed.opacity(0.3), radius: 4, x: 0, y: 2)
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

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("채팅")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("매칭된 상대와 대화를 나누어보세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Chat List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if viewModel.channels.isEmpty && !viewModel.isLoading {
                            EmptyStateView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                        } else {
                            ForEach(viewModel.channels) { channel in
                                ChatRowView(channel: channel)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .overlay {
                    if viewModel.isLoading && viewModel.channels.isEmpty {
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if viewModel.channels.isEmpty {
                viewModel.getChannels()
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.circle")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("채팅방이 없습니다")
                .font(.headline)
                .foregroundColor(.gray)
        }
    }
}
