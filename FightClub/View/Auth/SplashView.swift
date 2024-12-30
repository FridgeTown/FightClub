import SwiftUI

struct SplashView: View {
    @StateObject private var viewModel = SplashViewModel()
    @State private var showMainView = false
    @State private var showWelcomeView = false
    
    var body: some View {
        ZStack {
            // 배경
            Color.background.ignoresSafeArea()
            
            // 로고 및 로딩 인디케이터
            VStack(spacing: 20) {
                Image("title_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200)
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
        .onAppear {
            checkAuthStatus()
        }
        .fullScreenCover(isPresented: $showMainView) {
            MainTabView()
        }
        .fullScreenCover(isPresented: $showWelcomeView) {
            LoginView()
        }
    }
    
    private func checkAuthStatus() {
        Task {
            do {
                let isAuthenticated = try await viewModel.checkAuthentication()
                await MainActor.run {
                    if isAuthenticated {
                        showMainView = true
                    } else {
                        showWelcomeView = true
                    }
                }
            } catch {
                await MainActor.run {
                    showWelcomeView = true
                }
            }
        }
    }
}

@MainActor
class SplashViewModel: ObservableObject {
    @Published var isLoading = false
    private let tokenManager = TokenManager.shared
    private let authService = AuthService.shared
    
    func checkAuthentication() async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        // 토큰 존재 여부 확인
        guard let token = try? tokenManager.getAccessToken() else {
            print("token manager 에 토큰이 존재하지 않습니다.")
            return false
        }
        
        do {
            // 토큰 유효성 검증 API 호출
            let isValid = try await authService.validateToken()
            return isValid
        } catch AuthError.invalidCredentials {
            print("토큰이 유효하지 않습니다.")
            try? tokenManager.clearAllTokens()
            return false
        } catch {
            print("토큰 검증 중 오류 발생: \(error.localizedDescription)")
            return false
        }
    }
}
