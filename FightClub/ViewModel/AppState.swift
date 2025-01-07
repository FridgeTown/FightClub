//
//  AppState.swift
//  FightClub
//
//  Created by 김지훈 on 07/01/2025.
//

import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    
    init() {
        checkLoginStatus()
    }
    
    func checkLoginStatus() {
        do {
            let _ = try TokenManager.shared.getAccessToken()
            self.isLoggedIn = true
        } catch {
            self.isLoggedIn = false
        }
    }
    
    func logIn() {
        self.isLoggedIn = true
    }
    
    func logOut() {
        do {
            try TokenManager.shared.clearAllTokens()
            self.isLoggedIn = false
        } catch {
            print("토큰 삭제 실패:", error)
        }
    }
}
