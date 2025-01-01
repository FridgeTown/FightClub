//
//  ChatListView.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI
import TalkPlus

struct ChatListView: View {
    @StateObject private var viewModel: ChatListModel
    @State private var selectedChannelId: String?
    
    init(viewModel: ChatListModel = DIContainer.shared.makeChatListViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    headerView
                    
                    if viewModel.channel.isEmpty {
                        EmptyStateView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.channel) { channel in
                                    ChatRowView(channel: channel)
                                        .onTapGesture {
                                            selectedChannelId = channel.id
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            Task {
                await viewModel.getChatList()
            }
        }
        .sheet(item: $selectedChannelId) { channelId in
            if let tpChannel = viewModel.getTPChannel(for: channelId) {
                ChatRoomView(tpChannel: tpChannel)
            }
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("채팅")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            Text("스파링 파트너와 대화를 나누어보세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top)
    }
}

struct ChatRowView: View {
    let channel: ChatChannel
    
    var body: some View {
        HStack(spacing: 16) {
            // URL 디버깅 출력
            let urlString = channel.profileImageUrl ?? ""
            let _ = print("Profile URL for \(channel.name): \(urlString)")
            
            AsyncImage(url: URL(string: urlString)) { phase in
                switch phase {
                case .empty:
//                    ProgressView()
//                        .frame(width: 56, height: 56)
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
                case .failure(let error):
                    // 에러 디버깅 추가
                    let _ = print("Image loading failed: \(error.localizedDescription)")
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

//// MARK: - Preview
//struct ChatListView_Previews: PreviewProvider {
//    static var previews: some View {
//        ChatListView(activeChats: [
//            Chat(id: 1, userName: "Boxer Kim", lastMessage: "오늘 스파링 어떠셨나요?"),
//            Chat(id: 2, userName: "Fighter Lee", lastMessage: "다음 스파링 일정 잡아요!"),
//            Chat(id: 3, userName: "Champion Park", lastMessage: "좋은 경기였습니다!")
//        ])
//    }
//}
