//
//  LoginView.swift
//  FightClub
//
//  Created by 김지훈 on 26/12/2024.
//

import SwiftUI
import GoogleSignInSwift
import AuthenticationServices
//import GoogleSignIn

class SignupData: ObservableObject {
    @Published var gender: String? = nil
    @Published var age: Int? = nil
    @Published var weight: Float? = nil
    @Published var height: Float? = nil
    @Published var nickname: String? = nil
    @Published var email: String? = nil // email 추가
    @Published var provider: String? = nil // provider 추가
    
    func toDictionary() -> [String: Any] {
        return [
            "gender": gender ?? "",
            "age": age ?? 0,
            "weight": weight ?? 0.0,
            "height": height ?? 0.0,
            "nickname": nickname ?? "",
            "email": email ?? "",
            "provider": provider ?? ""
        ]
    }
} // 이후에 UserModel로 대체

struct LoginView: View {
    @StateObject var googleAuthViewModel = GoogleOAuthViewModel()
    @StateObject private var appleSignInCoordinator = AppleSignInCoordinator()
    @StateObject private var signupData = SignupData()
    @State private var showMainView = false
    @State private var showSignupView = false
    
    // path 추가
    @State private var path: [String] = [] // NavigationStack 경로 관리

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
                        googleAuthViewModel.signIn()
                        Task {
                            while googleAuthViewModel.givenEmail == nil {
                                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms 대기
                            }
                            signupData.email = googleAuthViewModel.givenEmail
                            print("Updated signupData.email in LoginView: \(signupData.email ?? "nil")")
                            showSignupView = true
                        }
                    }
                    .frame(width: 200, height: 40)
                    
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
                                        
                                        // Save idToken to UserDefaults
                                        UserDefaults.standard.set(token, forKey: "idToken")
                                        Task {
                                            await appleSignInCoordinator.checkUserRegistration(
                                                email: appleSignInCoordinator.email!,
                                                provider: "apple",
                                                idToken: token
                                            )
                                        }
                                    }
                                }
                            case .failure(let error):
                                print("Apple Sign-In failed: \(error.localizedDescription)")
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
            SignupFirstView(
                path: $path, // path 전달
                signupData: signupData,
                googleAuthViewModel: googleAuthViewModel
            )
        }
        .onChange(of: googleAuthViewModel.authState) { oldState, newState in
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
