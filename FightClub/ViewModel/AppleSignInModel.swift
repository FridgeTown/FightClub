//
//  AppleSignInModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/28/24.
//

import Foundation
import AuthenticationServices
import SwiftUI

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
    
    // MARK: - 실제로 애플 로그인을 시작하는 메서드 (선택사항)
    // SwiftUI의 SignInWithAppleButton 대신 직접 ASAuthorizationController를 사용하는 패턴
    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - 로그인 후 서버에 가입 여부 확인
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
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.authState = .none
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    // 성공 시 호출
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // 이메일
            let fetchedEmail = credential.email ?? credential.user
            self.email = fetchedEmail
            
            // idToken
            if let tokenData = credential.identityToken,
               let idToken = String(data: tokenData, encoding: .utf8) {
                
                // oauthUserData에 저장
                oauthUserData.idToken = idToken
                oauthUserData.oauthId = credential.user
                
                // 디버깅용 로그
                print("Apple ID Token: \(idToken)")
                print("Apple Email: \(fetchedEmail)")
                
                // UserDefaults 저장 (선택)
                UserDefaults.standard.set(idToken, forKey: "idToken")
                
                // 서버로 가입 여부 조회
                Task {
                    await checkUserRegistration(
                        email: fetchedEmail,
                        provider: "apple",
                        idToken: idToken
                    )
                }
            } else {
                print("애플 로그인 성공했으나 identityToken이 없습니다.")
                self.errorMessage = "애플 로그인 토큰 추출 실패"
            }
        }
    }
    
    // 실패 시 호출
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign In 실패:", error.localizedDescription)
        self.errorMessage = error.localizedDescription
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    @objc func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // iOS13 이상에서 UIScene 기반 앱이라면 다음처럼
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
