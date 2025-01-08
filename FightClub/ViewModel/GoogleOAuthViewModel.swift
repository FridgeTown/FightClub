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
    /*
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
     */
    func checkUserInfo() async {
        if let user = GIDSignIn.sharedInstance.currentUser {
            if let email = user.profile?.email {
                self.givenEmail = email
            }
            oauthUserData.oauthId = user.userID ?? ""
            oauthUserData.idToken = user.idToken?.tokenString ?? ""
            
            // 디버깅용 로그 추가
            print("추출된 idToken: \(oauthUserData.idToken)")
            
            // UserDefaults 저장
            UserDefaults.standard.set(oauthUserData.idToken, forKey: "idToken")
            
            // 저장된 값 검증
            if let savedToken = UserDefaults.standard.string(forKey: "idToken") {
                print("UserDefaults에 저장된 idToken: \(savedToken)")
            } else {
                print("UserDefaults 저장 실패")
            }
            
            await checkUserRegistration(email: self.givenEmail ?? "", provider: "google", idToken: oauthUserData.idToken)
        } else {
            self.errorMessage = "error: Not Logged In"
        }
    }
    /*
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
    */
    
    func signIn() {
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
            return
        }

        _ = GIDConfiguration(clientID: "YOUR_CLIENT_ID")

        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController
        ) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = "error: \(error.localizedDescription)"
                return
            }

            guard let user = result?.user else {
                self?.errorMessage = "No user returned"
                return
            }

            // 이메일 및 ID 토큰 설정
            self?.givenEmail = user.profile?.email
            self?.oauthUserData.idToken = user.idToken?.tokenString ?? ""

            // 디버깅 로그
            print("Fetched email: \(self?.givenEmail ?? "N/A")")
            print("Fetched idToken: \(self?.oauthUserData.idToken ?? "N/A")")

            // 사용자 정보 확인 호출
            Task {
                await self?.checkUserInfo()
            }
        }
    }
    
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}
