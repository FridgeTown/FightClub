//
//  DemoViewModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import Foundation

class DemoViewModel: ObservableObject {
    @Published private(set) var items: [ItemModel] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager: NetworkManagerProtocol
    
    init(networkManager: NetworkManagerProtocol = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
//    @MainActor
//    func fetchItems() async {
//        isLoading = true
//        do {
//            items = try await networkManager.request(.getItems)
//            print(items)
//        } catch {
//            errorMessage = error.localizedDescription
//        }
//        isLoading = false
//    }
}
