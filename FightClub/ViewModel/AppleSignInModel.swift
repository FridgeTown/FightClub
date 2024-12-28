//
//  AppleSignInModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/28/24.
//

import Foundation
import AuthenticationServices

class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ObservableObject {
    @Published var email: String?
    @Published var userIdentifier: String?
    @Published var idToken: String?
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            self.userIdentifier = appleIDCredential.user
            self.email = appleIDCredential.email
            
            if let tokenData = appleIDCredential.identityToken,
               let token = String(data: tokenData, encoding: .utf8) {
                self.idToken = token
            }
            
//            // TokenManager에 토큰 저장
//            if let token = self.idToken {
//                do {
//                    try TokenManager.shared.saveAccessToken(token)
//                } catch {
//                    print("토큰 저장 실패: \(error.localizedDescription)")
//                }
//            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Authorization failed: \(error.localizedDescription)")
    }
}
