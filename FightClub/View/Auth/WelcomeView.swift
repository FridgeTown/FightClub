import SwiftUI
import GoogleSignInSwift
import AuthenticationServices

struct WelcomeView: View {
    @StateObject private var viewModel = WelcomeViewModel()
    @State private var showSignUpView = false
    @State private var showMainView = false
    
    var body: some View {
        ZStack {
            // 배경
            Color(.background).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // 로고
                Image("title_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200)
                
                Text("스파링 파트너를 찾아보세요")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.mainRed)
                
                Spacer()
                
                // 로그인 버튼들
                VStack(spacing: 15) {
                    // Google 로그인
                    GoogleSignInButton {
                        Task {
                            await viewModel.handleGoogleSignIn()
                        }
                    }
                    .frame(height: 50)
                    .cornerRadius(8)
                    
                    // Apple 로그인
                    SignInWithAppleButton { request in
                        request.requestedScopes = [.email]
                    } onCompletion: { result in
                        Task {
                            await viewModel.handleAppleSignIn(result)
                        }
                    }
                    .frame(height: 50)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
        .navigationDestination(isPresented: $showSignUpView) {
            SignUpView(email: viewModel.email)
        }
        .navigationDestination(isPresented: $showMainView) {
            HomeView()
        }
        .onChange(of: viewModel.authState) { newState in
            switch newState {
            case .registered:
                showMainView = true
            case .needsSignUp:
                showSignUpView = true
            case .none:
                break
            }
        }
    }
}

class WelcomeViewModel: ObservableObject {
    @Published var authState: AuthState = .none
    @Published var email: String = ""
    
    private let authService = AuthService.shared
    private let tokenManager = TokenManager.shared
    
    enum AuthState {
        case none
        case registered
        case needsSignUp
    }
    
    func handleGoogleSignIn() async {
//        do {
//            let result = try await GoogleSignInService.signIn()
//            await checkUserRegistration(email: result.email)
//        } catch {
//            print("Google 로그인 실패: \(error.localizedDescription)")
//        }
    }
    
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let email = appleIDCredential.email {
                await checkUserRegistration(email: email)
            }
        case .failure(let error):
            print("Apple 로그인 실패: \(error.localizedDescription)")
        }
    }
    
    private func checkUserRegistration(email: String) async {
        do {
            let isRegistered = try await authService.checkUserExists(email: email)
            await MainActor.run {
                self.email = email
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
