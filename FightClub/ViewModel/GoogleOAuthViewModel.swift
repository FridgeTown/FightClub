//
//  GoogleOAuthViewModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/28/24.
//

import GoogleSignIn
import SwiftUI

@MainActor
class GoogleOAuthViewModel: ObservableObject {
    @Published var oauthUserData = OAuthUserData()
    @Published var errorMessage: String?
    @Published var givenEmail: String?
    @Published var authState: AuthState = .none
    
    private let authService = AuthService.shared
    
    enum AuthState {
        case none
        case registered
        case needsSignUp
    }
    
    func checkUserRegistration(email: String, provider: String, idToken: String) async {
            do {
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
    
    func checkUserInfo() async {
        if GIDSignIn.sharedInstance.currentUser != nil {
            let user = GIDSignIn.sharedInstance.currentUser
            guard let user = user else {
                return
            }
            if let email = user.profile?.email {
                self.givenEmail = email
            }
            oauthUserData.oauthId = user.userID ?? ""
            oauthUserData.idToken = user.idToken?.tokenString ?? ""
            await checkUserRegistration(email: self.givenEmail ?? "", provider: "google", idToken: oauthUserData.idToken)
            print("토큰:", user.idToken?.tokenString ?? "")
        } else {
            self.errorMessage = "error: Not Logged In"
        }
    }
    
    func signIn() {
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
            return
        }
        
        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController)
        { [weak self] _, error in
            if let error = error {
                self?.errorMessage = "error: \(error.localizedDescription)"
            }
            Task {
                await self?.checkUserInfo()
            }
        }
    }
        
        func signOut() {
            GIDSignIn.sharedInstance.signOut()
        }
    }
