//
//  HomeViewModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/30/24.
//

import Combine
import Foundation

class HomeViewModel: ObservableObject {
    @Published private(set) var users: APIResponse<[MatchUser]> = APIResponse(
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
    func getUsers() async {
        isLoading = true
        do {
            users = try await networkManager.requestArray(.getUserRecommend)
            print(users)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
