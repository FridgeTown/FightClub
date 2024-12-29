//
//  LoginView.swift
//  FightClub
//
//  Created by 김지훈 on 26/12/2024.
//

import SwiftUI
import GoogleSignInSwift
import AuthenticationServices

struct LoginView: View {
    @StateObject private var viewModel = GoogleOAuthViewModel()
    @StateObject private var appleSignInCoordinator = AppleSignInCoordinator()
    @State private var showMainView = false
    @State private var showSignupView = false
    
    var body: some View {
        ZStack {
            Color(red: 0.89, green: 0.1, blue: 0.1)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Text("Welcome to FightClub")
                    .font(Font.custom("BebasNeue", size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(0.8), radius: 4, x: 2, y: 2)

                Text("간편하게 시작하기")
                    .foregroundColor(.white)

                VStack(spacing: 20) {
                    GoogleSignInButton(scheme: .light, style: .wide) {
                        viewModel.signIn()
                    }.frame(width: 200, height: 40)
                    
                    
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    if let email = appleIDCredential.email {
                                        appleSignInCoordinator.email = email
                                    } else {
                                        appleSignInCoordinator.email = appleIDCredential.user
                                    }
                                        if let tokenData = appleIDCredential.identityToken,
                                           let token = String(data: tokenData, encoding: .utf8) {
                                            appleSignInCoordinator.oauthUserData.idToken = token
                                            appleSignInCoordinator.oauthUserData.oauthId = appleIDCredential.user
                                            
                                            Task {
                                                await appleSignInCoordinator.checkUserRegistration(email: appleSignInCoordinator.email!, provider: "apple", idToken: token)
                                            }
                                        }
                                }
                            case .failure(let error):
                                appleSignInCoordinator.errorMessage = "로그인 실패: \(error.localizedDescription)"
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(width: 200, height: 40)
                }
                .padding(.horizontal, 40)
            }
            .padding(.top, 80)
        }
        .fullScreenCover(isPresented: $showMainView) {
            MainTabView()
        }
        .fullScreenCover(isPresented: $showSignupView) {
            SignupFirstView()
        }
        .onChange(of: viewModel.authState) { oldState, newState in
            switch newState {
            case .registered:
                showMainView = true
            case .needsSignUp:
                showSignupView = true
            case .none:
                break
            }
        }
        .onChange(of: appleSignInCoordinator.authState) { oldState, newState in
            switch newState {
            case .registered:
                showMainView = true
            case .needsSignUp:
                showSignupView = true
            case .none:
                break
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
