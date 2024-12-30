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
    
    func checkAuthentication() async throws -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        // 토큰 존재 여부 확인
        guard let token = try? tokenManager.getAccessToken() else {
            print("로컬에 저장된 토큰 ")
            return false
        }
        
        // TODO: 토큰 유효성 검증 API 호출
        // let isValid = try await AuthService.validateToken(token)
        // return isValid
        
        return true
    }
}
