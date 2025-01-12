//
//  HomeViewModel.swift
//  FightClub
//1
//  Created by Edward Lee on 12/30/24.
//

import Foundation
import UIKit
import Combine

class MyProfileViewModel: ObservableObject {
    @Published private(set) var profileData: UserData? = nil
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessMessage = false
    @Published var showLogoutAlert = false
    
    private let networkManager: NetworkManager
    
    init(networkManager: NetworkManager = NetworkManager.shared) {
        self.networkManager = networkManager
    }
    
    func loadUserInfo() async {
        isLoading = true
        do {
            let response: APIResponse<UserData> = try await networkManager.request(.getUserInfo)
            profileData = response.data
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func updateProfileImage(_ image: UIImage) async {
        isLoading = true
        do {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                errorMessage = "이미지 변환에 실패했습니다."
                return
            }
            
            let response: APIResponse<String> = try await networkManager.request(.updateProfileImage(imageData: imageData))
            
            if response.status == 200 {
                showSuccessMessage = true
                await loadUserInfo()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func logout() async {
        do {
            try TokenManager.shared.clearAllTokens()
        } catch {
            errorMessage = "로그아웃 실패: \(error.localizedDescription)"
        }
    }
} 
