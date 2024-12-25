//
//  DIContainer.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import Foundation

class DIContainer {
    static let shared = DIContainer()
    private init() {}
    
    func makeHomeViewModel() -> HomeViewModel {
        let networkManager = NetworkManager.shared
        return HomeViewModel(networkManager: networkManager)
    }
}
