//
//  LiveListViewModel.swift
//  FightClub
//
//  Created by Edward Lee on 1/9/25.
//

import Foundation
import Combine

class LiveListViewModel: ObservableObject {
    @Published private(set) var liveList: APIResponse<[LiveListModel]> = APIResponse(
        status: 200,
        message: "",
        data: []
    )
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
    @MainActor
    func fetchLiveList() async {
        isLoading = true
        do {
            print("fetchLiveList")
            liveList = try await networkManager.requestArray(.getLiveList)
            print("liveList", liveList)
        } catch {
            print(error)
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
