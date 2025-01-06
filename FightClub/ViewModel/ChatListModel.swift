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
        
        // 현재 사용자 ID
        let currentUserId = UserDataManager.shared.getUserData()?.id.toString()
        
        // 멤버 정보 디버깅
        if let members = tpChannel.getMembers() as? [TPMember] {
            print("Channel members count: \(members.count)")
            for member in members {
                print("Member ID: \(member.getId())")
                print("Member Profile URL: \(member.getProfileImageUrl() ?? "nil")")
            }
            
            // 상대방 찾기
            if let otherMember = members.first(where: { $0.getId() != currentUserId }) {
                self.name = otherMember.getUsername() ?? tpChannel.getName() ?? ""
                self.profileImageUrl = otherMember.getProfileImageUrl()
                print("Other member found - Name: \(self.name), Profile URL: \(self.profileImageUrl ?? "nil")")
            } else {
                self.name = tpChannel.getName() ?? ""
                self.profileImageUrl = nil
                print("No other member found")
            }
        } else {
            self.name = tpChannel.getName() ?? ""
            self.profileImageUrl = nil
            print("No members found in channel")
        }
        
        self.lastMessage = tpChannel.getLastMessage()?.getText() ?? ""
        self.lastMessageTime = tpChannel.getLastMessage()?.getCreatedAt() ?? 0
        self.unreadCount = Int(tpChannel.getUnreadCount())
    }
}



class ChatListModel: ObservableObject {
    @Published private(set) var channel: [ChatChannel] = []
    private var tpChannels: [TPChannel] = []
    
    private var channelMap: [String: TPChannel] = [:]
    
    var sortedChannels: [ChatChannel] {
        channel.sorted { channel1, channel2 in
            // 최신 메시지 시간 기준으로 정렬
            channel1.lastMessageTime > channel2.lastMessageTime
        }
    }
    
    func getChatList() async {
        TalkPlus.sharedInstance()?.getChannels(nil,
            success: { tpChannels, hasNext in
            guard let tpChannels = tpChannels else { return }
            self.tpChannels = tpChannels
            self.channelMap = Dictionary(uniqueKeysWithValues:
                tpChannels.map { ($0.getId(), $0) }
            )
            let chatChannels = tpChannels.map { ChatChannel(from: $0) }
            DispatchQueue.main.async {
                self.channel = chatChannels
            }
        }, failure: { (errorCode, error) in
            print("getChatList failed", errorCode, error ?? "")
        })
    }
    
    func getTPChannel(for channelId: String) -> TPChannel? {
        return tpChannels.first { $0.getId() == channelId }
    }
}
