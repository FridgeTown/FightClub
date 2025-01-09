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
    
    @Published private(set) var response: APIResponse<String?> = APIResponse(
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
            print(response.status)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
