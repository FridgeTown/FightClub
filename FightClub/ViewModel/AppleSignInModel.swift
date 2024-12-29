//
//  AppleSignInModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/28/24.
//

import Foundation
import AuthenticationServices

@MainActor
class AppleSignInCoordinator: NSObject, ObservableObject {
    @Published var oauthUserData = OAuthUserData()
    @Published var errorMessage: String?
    @Published var email: String?
    @Published var authState: AuthState = .none
    
    private let authService = AuthService.shared
    
    enum AuthState {
        case none
        case registered
        case needsSignUp
    }
    
    func checkUserRegistration(email: String, provider: String, idToken: String) async {
        do {
            print(email, provider, idToken)
            let isRegistered = try await authService.checkUserExists(email: email, provider: provider, token: idToken)
            await MainActor.run {
                if isRegistered {
                    self.authState = .registered
                } else {
                    self.authState = .needsSignUp
                }
            }
        } catch {
            print("사용자 확인 실패: \(error.localizedDescription)")
        }
    }
}
