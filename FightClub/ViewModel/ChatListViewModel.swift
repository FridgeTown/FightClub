import Foundation
import TalkPlus
import Combine

class ChatListViewModel: ObservableObject {
    @Published private(set) var channels: [ChatChannel] = []
    @Published private(set) var isLoading = false
    private var tpChannels: [TPChannel] = []
    
    func getChannels() {
        print("ChatListViewModel - Starting to get channels")
        isLoading = true
        TalkPlus.sharedInstance()?.getChannels(nil,
            success: { [weak self] tpChannels, hasNext in
                print("ChatListViewModel - Got channels from TalkPlus")
                guard let self = self,
                      let tpChannels = tpChannels else {
                    print("ChatListViewModel - Failed to get channels: self or tpChannels is nil")
                    self?.isLoading = false
                    return
                }
                
                print("ChatListViewModel - Retrieved \(tpChannels.count) channels")
                self.tpChannels = tpChannels
                let chatChannels = tpChannels.map { ChatChannel(from: $0) }
                
                DispatchQueue.main.async {
                    self.channels = chatChannels.sorted { $0.lastMessageTime > $1.lastMessageTime }
                    self.isLoading = false
                    print("ChatListViewModel - Updated channels list with \(self.channels.count) channels")
                }
            }, failure: { [weak self] (errorCode, error) in
                print("ChatListViewModel - Failed to get channels: \(errorCode), \(String(describing: error))")
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            })
    }
    
    func getTPChannel(for id: String) -> TPChannel? {
        print("ChatListViewModel - Getting TPChannel for id: \(id)")
        print("ChatListViewModel - Available channels: \(tpChannels.map { $0.getId() })")
        
        let channel = tpChannels.first { $0.getId() == id }
        if let channel = channel {
            print("ChatListViewModel - Found channel: \(channel.getId())")
        } else {
            print("ChatListViewModel - No channel found for id: \(id)")
        }
        return channel
    }
} 