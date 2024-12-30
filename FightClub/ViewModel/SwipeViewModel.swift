//
//  SwipeViewModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/31/24.
//

import Combine
import Foundation

class SwipeViewModel: ObservableObject {
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
