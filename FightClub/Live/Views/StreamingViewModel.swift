//
//  StreamingViewModel.swift
//  FightClub
//
//  Created by Edward Lee on 1/9/25.
//

import Foundation
import Combine

class StreamingViewModel: ObservableObject {
    
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    @Published private(set) var response: APIResponse<LiveStreamResponse> = APIResponse(
        status: 0,
        message: "",
        data: nil
    )
    
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
    @MainActor
    func postLiveStream(channelId: String, place: String) async {
        isLoading = true
        do {
            response = try await networkManager.request(.postLiveStart(channelId: channelId, place: place))
            print("리스폰스", response.status)
            if let id = response.data?.id {
                print("채팅방 ID:", id)
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error:", error)
        }
        isLoading = false
    }
    
    @MainActor
    func postEndLiveStream(matchId: String) async {
        isLoading = true
        do {
            response = try await networkManager.request(.postEndLiveMatch(matchId: matchId))
        } catch {
            errorMessage = error.localizedDescription
            print("Error:", error)
        }
        isLoading = false
    }
    
}


struct LiveStreamResponse: Codable {
    let id: String
    
    enum CodingKeys: String, CodingKey {
        case id = "chatRoomId"
    }
}
