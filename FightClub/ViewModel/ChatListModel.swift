//
//  ChatListModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/31/24.
//

import Foundation
import TalkPlus
import Combine

class ChatListModel: ObservableObject {
    @Published var channel = [TPChannel]()
    
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
    func getChatList() async {
        TalkPlus.sharedInstance()?.getChannels(nil,
            success: { tpChannels, hasNext in
            // SUCCESS
            // If 'hasNext' is true, call this method with the last object in 'tpChannels'.
            print("채팅 가져옴!", tpChannels)
            for channel in tpChannels! {
                print("채팅 이름: ", channel.getLastMessage().getText())
            }
            self.channel = tpChannels!
        }, failure: { (errorCode, error) in
            print("실패임! ", errorCode, error)
        })
    }
}
