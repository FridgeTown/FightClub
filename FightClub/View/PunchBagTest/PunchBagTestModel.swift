//
//  PunchBagTestModel.swift
//  FightClub
//
//  Created by Edward Lee on 1/16/25.
//

import Foundation
import Combine

class PunchBagTestModel: ObservableObject {
    
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    @Published private(set) var response: APIResponse<PunchGameModel> = APIResponse(
        status: 0,
        message: "",
        data: nil
    )
    
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
    @MainActor
    func postPunchgameStart(channelId: String) async {
        isLoading = true
        do {
            response = try await networkManager.request(.postPunchGamgeStart(channelId: channelId))
            print("리스폰스", response.data)
        } catch {
            errorMessage = error.localizedDescription
            print("Error:", error)
        }
        isLoading = false
    }
}


