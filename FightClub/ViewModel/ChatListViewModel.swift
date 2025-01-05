import Foundation
import TalkPlus
import Combine

class ChatListViewModel: ObservableObject {
    @Published private(set) var channels: [ChatChannel] = []
    @Published private(set) var isLoading = false
    private var tpChannels: [TPChannel] = []
    
    func getChannels() {
        isLoading = true
        TalkPlus.sharedInstance()?.getChannels(nil,
            success: { [weak self] tpChannels, hasNext in
                guard let self = self,
                      let tpChannels = tpChannels else {
                    self?.isLoading = false
                    return
                }
                
                self.tpChannels = tpChannels
                let chatChannels = tpChannels.map { ChatChannel(from: $0) }
                
                DispatchQueue.main.async {
                    self.channels = chatChannels.sorted { $0.lastMessageTime > $1.lastMessageTime }
                    self.isLoading = false
                }
            }, failure: { [weak self] (errorCode, error) in
                print("채팅방 목록 가져오기 실패: \(errorCode), \(String(describing: error))")
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            })
    }
    
    func getTPChannel(for id: String) -> TPChannel? {
        return tpChannels.first { $0.getId() == id }
    }
} 