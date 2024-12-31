//
//  MatchRequestModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/31/24.
//


import Foundation

class MatchRequestModel: ObservableObject {
    @Published private(set) var matchs: APIResponse<[MatchRequest]> = APIResponse(
        status: 200,
        message: "",
        data: []
    )
    
    @Published private(set) var response: APIResponse<String?> = APIResponse(
        status: 0,
        message: "",
        data: nil)
    
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager: NetworkManagerProtocol
    
    init(networkManager: NetworkManagerProtocol = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
    @MainActor
    func getPendingList() async {
        isLoading = true
        do {
            matchs = try await networkManager.request(.getPendingMatch)
            print(matchs)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    @MainActor
    func acceptMatch(matchId: Int) async {
        isLoading = true
        do {
            let id = matchId.toString()
            response = try await networkManager.request(.postAcceptRequest(matchID: id))
            print("Match accepted")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
