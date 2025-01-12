//
//  HomeViewModel.swift
//  FightClub
//1
//  Created by Edward Lee on 12/30/24.
//

import Foundation
import UIKit
import Combine

// MARK: - MyProfileViewModel
@MainActor
final class MyProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var profileData: UserData? = nil
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var showLogoutAlert = false
    
    // MARK: - Private Properties
    private let networkManager: NetworkManager
    private let imageCompressionQuality: CGFloat = 0.7
    private let maxImageSize: CGFloat = 1024
    
    // MARK: - Initialization
    init(networkManager: NetworkManager = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
    // MARK: - Public Methods
    /// 사용자 정보를 서버로부터 로드합니다.
    func loadUserInfo() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: APIResponse<UserData> = try await networkManager.request(.getUserInfo)
            profileData = response.data
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 프로필 이미지를 업데이트합니다.
    /// - Parameter image: 업로드할 새로운 프로필 이미지
    func updateProfileImage(_ image: UIImage) async {
        isLoading = true
        
        do {
            let resizedImage = resizeImage(image)
            print("이미지 리사이즈 완료: \(resizedImage.size)")
            
            let response: APIResponse<UserData?> = try await networkManager.uploadProfileImage(image: resizedImage)
            print("서버 응답 받음: \(response)")
            
            if response.status == 200 {
                showSuccessMessage = true
                print("프로필 이미지 업로드 성공")
                
                // AuthService를 사용하여 사용자 정보 갱신
                let isValid = try await AuthService.shared.validateToken()
                if isValid {
                    print("토큰 유효성 검사 성공")
                    await loadUserInfo()
                    // UserDataManager 업데이트 확인
                    if let profileUrl = UserDataManager.shared.profileImageUrl {
                        print("새로운 프로필 이미지 URL: \(profileUrl)")
                    }
                } else {
                    print("토큰 유효성 검사 실패")
                    errorMessage = "사용자 정보를 갱신할 수 없습니다."
                }
            } else {
                print("서버 응답 상태 코드 에러: \(response.status)")
                errorMessage = "프로필 이미지 업데이트에 실패했습니다."
            }
        } catch {
            print("프로필 이미지 업로드 에러: \(error)")
            errorMessage = "프로필 이미지 업로드 중 오류가 발생했습니다: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// 로그아웃을 수행합니다.
    func logout() async {
        do {
            try TokenManager.shared.clearAllTokens()
        } catch {
            errorMessage = "로그아웃 실패: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Methods
    /// 이미지 크기를 조정합니다.
    private func resizeImage(_ image: UIImage) -> UIImage {
        let scale = min(maxImageSize / image.size.width, maxImageSize / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// 이미지 업로드 응답을 처리합니다.
    private func handleImageUploadResponse(_ response: APIResponse<UserData?>) {
        if response.status == 200 {
            showSuccessMessage = true
            if let userData = response.data {
                self.profileData = userData
            }
        } else {
            errorMessage = "프로필 이미지 업데이트에 실패했습니다."
        }
    }
} 
