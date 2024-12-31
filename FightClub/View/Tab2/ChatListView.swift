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
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                if viewModel.channel.isEmpty {
                    EmptyStateView()
                } else {
                    List {
                        ForEach(viewModel.channel) { channel in
                            ChatRowView(channel: channel)
                                .onTapGesture {
                                    selectedChannelId = channel.id
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("채팅")
            .navigationBarTitleDisplayMode(.inline)
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
}


// ChatRowView 수정
struct ChatRowView: View {
    let channel: ChatChannel
    
    var body: some View {
        HStack(spacing: 16) {
            // 프로필 이미지
            AsyncImage(url: URL(string: channel.profileImageUrl ?? "")) { phase in
                switch phase {
                case .empty:
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                case .success(let image):
                    image
                        .resizable()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .failure:
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(channel.name)
                    .font(.headline)
                
                Text(channel.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if channel.unreadCount > 0 {
                Text("\(channel.unreadCount)")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.mainRed)
                    .clipShape(Circle())
            }
        }
        .contentShape(Rectangle())  // 전체 영역 탭 가능하도록
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
