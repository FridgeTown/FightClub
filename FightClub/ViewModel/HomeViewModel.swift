//
//  HomeViewModel.swift
//  FightClub
//1
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
    func getUsers() async {
        isLoading = true
        do {
            users = try await networkManager.requestArray(.getUserRecommend)
            print("getUsers() in HomeViewModel:", users)
        } catch {
            errorMessage = error.localizedDescription
            print("errorMessage", errorMessage)
        }
        isLoading = false
    }
    
    @MainActor
    func postRequest(id: String) async {
        isLoading = true
        do {
            response = try await networkManager.request(.postMatchRequest(opponentID: id))
            print(response.status)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
