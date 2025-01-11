//
//  SplassView.swift
//  FightClub
//
//  Created by JiHoon Kim
//

import SwiftUI

struct SplashView: View {
    @StateObject private var viewModel = SplashViewModel()
    @State private var showMainView = false
    @State private var showLoginView = false
    
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            
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
            
            // 알림 오버레이 추가
            NotificationOverlay()
        }
        .onAppear {
            checkAuthStatus()
            // 로그인 성공 시 SSE 서비스 시작
            if UserDataManager.shared.getUserData() != nil {
                NotificationService.shared.startService()
            }
        }
        // isAuthenticated == true → MainTabView
        .fullScreenCover(isPresented: $showMainView) {
            MainTabView()
        }
        // isAuthenticated == false → LoginView
        .fullScreenCover(isPresented: $showLoginView) {
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
                        showLoginView = true
                    }
                }
            } catch {
                // 에러 발생 시에도 로그인 화면으로
                await MainActor.run {
                    showLoginView = true
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
        
//        try? tokenManager.saveAccessToken("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJvbmVAZ21haWwuY29tIiwicm9sZSI6IlJPTEVfVVNFUiIsImlhdCI6MTczNTc1NjczMCwiZXhwIjoxNzM2MzYxNTMwfQ.xd7I-qBe0bzuMXKLGebUfXFxCnP7F-FA6pEgVP66Co8")
        // 토큰 존재 여부 확인
        guard let _ = try? tokenManager.getAccessToken() else {
            print("token manager에 토큰이 존재하지 않습니다.")
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
