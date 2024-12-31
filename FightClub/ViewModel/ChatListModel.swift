//
//  ChatListModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/31/24.
//

import Foundation
import TalkPlus
import Combine

struct ChatChannel: Identifiable {
    let id: String
    let name: String
    let lastMessage: String
    let lastMessageTime: Int
    let unreadCount: Int
    let profileImageUrl: String?
    
    init(from tpChannel: TPChannel) {
        self.id = tpChannel.getId()
        self.name = tpChannel.getName()
        self.lastMessage = tpChannel.getLastMessage().getText()
        self.lastMessageTime = tpChannel.getLastMessage().getCreatedAt()
        self.unreadCount = Int(tpChannel.getUnreadCount())
        self.profileImageUrl = tpChannel.getImageUrl()
    }
}

class ChatListModel: ObservableObject {
    @Published var channel = [ChatChannel]()
    @Published var tpChannels = [TPChannel]()  // TPChannel 저장용
    
    // TPChannel을 ID로 찾을 수 있는 Dictionary 추가
    private var channelMap: [String: TPChannel] = [:]
    
    @MainActor
    func getChatList() async {
        TalkPlus.sharedInstance()?.getChannels(nil,
            success: { tpChannels, hasNext in
            guard let tpChannels = tpChannels else { return }
            
            // TPChannel 저장
            self.tpChannels = tpChannels
            
            // Dictionary 업데이트
            self.channelMap = Dictionary(uniqueKeysWithValues:
                tpChannels.map { ($0.getId(), $0) }
            )
            
            // UI용 ChatChannel 변환
            let chatChannels = tpChannels.map { ChatChannel(from: $0) }
            self.channel = chatChannels
        }, failure: { (errorCode, error) in
            print("getChatList failed", errorCode, error ?? "")
        })
    }
    
    // ID로 TPChannel 찾기
    func getTPChannel(for id: String) -> TPChannel? {
        return channelMap[id]
    }
}
