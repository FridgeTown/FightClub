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
    
    func makeDemoViewModel() -> DemoViewModel {
        let networkManager = NetworkManager.shared
        return DemoViewModel(networkManager: networkManager)
    }
    
    func makeHomeViewModel() -> HomeViewModel {
        let networkManager = NetworkManager.shared
        return HomeViewModel(networkManager: networkManager)
    }
    
    func makeChatListViewModel() -> ChatListModel {
        let _ = NetworkManager.shared
        return ChatListModel()
    }
    
    func makeMatchRequestModel() -> MatchRequestModel {
        let networkManager = NetworkManager.shared
        return MatchRequestModel(networkManager: networkManager)
    }
    
    func makeStreamViewModel() -> StreamingViewModel {
        let networkManager = NetworkManager.shared
        return StreamingViewModel(networkManager: networkManager)
    }
    
    func makeLiveListModel() -> LiveListViewModel {
        let networkManager = NetworkManager.shared
        return LiveListViewModel(networkManager: networkManager)
    }
    
    @MainActor func makeMyProfileViewModel() -> MyProfileViewModel {
        let networkManager = NetworkManager.shared
        return MyProfileViewModel(networkManager: networkManager)
    }
    
    func makePunchRequestModel() -> PunchBagTestModel {
        let networkManager = NetworkManager.shared
        return PunchBagTestModel(networkManager: networkManager)
    }
}
