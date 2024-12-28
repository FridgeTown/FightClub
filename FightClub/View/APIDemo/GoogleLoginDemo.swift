//
//  GoogleLoginDemo.swift
//  FightClub
//
//  Created by Edward Lee on 12/28/24.
//

import SwiftUI
import GoogleSignInSwift
import AuthenticationServices

struct GoogleLoginDemo: View {
    @StateObject private var viewModel = GoogleOAuthViewModel()
    @StateObject private var appleSignInCoordinator = AppleSignInCoordinator()
    
    var body: some View {
        VStack {
            // Google 로그인
            GoogleSignInButton {
                viewModel.signIn()
            }
            .padding()
            
            // Apple 로그인
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential {
                            // 이메일과 유저 ID 저장
                            appleSignInCoordinator.email = appleIDCredential.email
                            appleSignInCoordinator.userIdentifier = appleIDCredential.user
                            
                            // 토큰 처리
                            if let tokenData = appleIDCredential.identityToken,
                               let token = String(data: tokenData, encoding: .utf8) {
                                appleSignInCoordinator.idToken = token
                            }
                        }
                    case .failure(let error):
                        print("Authorization failed: \(error.localizedDescription)")
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(width: 200, height: 40)
            .padding()
            
            // Google 로그인 결과
            VStack(alignment: .leading) {
                Text("Google 로그인 결과:")
                    .font(.headline)
                Text("이메일: \(viewModel.givenEmail ?? "")")
                Text("토큰: \(viewModel.oauthUserData.idToken)")
            }
            .padding()
            
            // Apple 로그인 결과
            VStack(alignment: .leading) {
                Text("Apple 로그인 결과:")
                    .font(.headline)
                Text("이메일: \(appleSignInCoordinator.email ?? "")")
                Text("토큰: \(appleSignInCoordinator.idToken ?? "")")
            }
            .padding()
        }
    }
}

#Preview {
    GoogleLoginDemo()
}
