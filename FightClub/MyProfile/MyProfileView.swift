//
//  MyProfile.swift
//  FightClub
//
//  Created by 김지훈 on 08/01/2025.
//

import SwiftUI
import PhotosUI
import Alamofire
import Foundation

// MARK: - MyProfileView

struct MyProfileView: View {
    @StateObject private var viewModel = MyProfileViewModel()
    @State private var selectedImage: UIImage? = nil
    @State private var showSplashView = false
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    LoadingView()
                } else {
                    ProfileMainContent(
                        viewModel: viewModel,
                        showImagePicker: $showImagePicker,
                        selectedImage: $selectedImage,
                        showSplashView: $showSplashView
                    )
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { newImage in
                if let image = newImage {
                    Task {
                        await viewModel.updateProfileImage(image)
                        selectedImage = nil
                    }
                }
            }
            .fullScreenCover(isPresented: $showSplashView) {
                SplashView()
            }
            .task {
                await viewModel.loadUserInfo()
            }
        }
    }
}

// MARK: - ProfileMainContent
private struct ProfileMainContent: View {
    @ObservedObject var viewModel: MyProfileViewModel
    @Binding var showImagePicker: Bool
    @Binding var selectedImage: UIImage?
    @Binding var showSplashView: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ProfileImageSection(
                    viewModel: viewModel,
                    showImagePicker: $showImagePicker,
                    selectedImage: $selectedImage
                )
                
                ProfileInfoSection(viewModel: viewModel)
                
                LogoutButton(viewModel: viewModel, showSplashView: $showSplashView)
                    .padding(.top, 32)
            }
            .padding()
        }
    }
}

// MARK: - ProfileImageSection
private struct ProfileImageSection: View {
    @ObservedObject var viewModel: MyProfileViewModel
    @Binding var showImagePicker: Bool
    @Binding var selectedImage: UIImage?
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                if let profileImageURL = UserDataManager.shared.profileImageUrl,
                   let url = URL(string: profileImageURL) {
                    AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 120, height: 120)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.mainRed, lineWidth: 2))
                                .transition(.opacity)
                        case .failure(_):
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60)
                                        .foregroundColor(.gray)
                                )
                                .overlay(Circle().stroke(Color.mainRed, lineWidth: 2))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .onAppear {
                        print("프로필 이미지 URL: \(profileImageURL)")
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60)
                                .foregroundColor(.gray)
                        )
                        .overlay(Circle().stroke(Color.mainRed, lineWidth: 2))
                }
                
                Button(action: {
                    showImagePicker = true
                }) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.mainRed)
                        .clipShape(Circle())
                }
            }
            
            if let nickname = viewModel.profileData?.nickname {
                Text(nickname)
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
    }
}

// MARK: - Loading View
private struct MyProfileLoadingView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .mainRed))
            .scaleEffect(1.5)
    }
}

// MARK: - Profile Info Section
private struct ProfileInfoSection: View {
    @ObservedObject var viewModel: MyProfileViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            if let profile = viewModel.profileData {
                ProfileInfoRow(title: "체급", value: profile.weightClass ?? "Not Found", icon: "figure.boxing")
                ProfileBodyInfoRow(profile: profile)
                ProfileInfoRow(title: "성별", value: profile.gender ?? "Not Found", icon: "person.fill")
                ProfileInfoRow(title: "포인트", value: "\(profile.points ?? 0)", icon: "star.fill")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
}

// MARK: - Profile Body Info Row
private struct ProfileBodyInfoRow: View {
    let profile: UserData
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "ruler")
                .font(.system(size: 24))
                .foregroundColor(Color.mainRed)
                .frame(width: 35)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("신체")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                Text("\(profile.height ?? 0)cm / \(profile.weight ?? 0)kg")
                    .font(.system(size: 18, weight: .medium))
            }
            Spacer()
        }
    }
}

// MARK: - Logout Button
private struct LogoutButton: View {
    let viewModel: MyProfileViewModel
    @Binding var showSplashView: Bool
    
    var body: some View {
        Button(action: { Task {try TokenManager.shared.clearAllTokens()} }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 20))
                Text("로그아웃")
                    .font(.system(size: 18, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.mainRed)
                    .shadow(color: Color.mainRed.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
}

// MARK: - Profile Info Row
private struct ProfileInfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color.mainRed)
                .frame(width: 35)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 18, weight: .medium))
            }
            Spacer()
        }
    }
}

// MARK: - Profile Image View
private struct ProfileImageView: View {
    let imageUrl: String?
    let selectedImage: UIImage?
    
    var body: some View {
        if let selectedImage = selectedImage {
            Image(uiImage: selectedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.mainRed, lineWidth: 2))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        } else if let imageUrlString = imageUrl,
                  let imageUrl = URL(string: imageUrlString),
                  !imageUrlString.isEmpty {
            AsyncImage(url: imageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.mainRed, lineWidth: 2))
                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            } placeholder: {
                ProfileImagePlaceholder()
            }
        } else {
            ProfileImagePlaceholder()
        }
    }
}

// MARK: - Profile Image Placeholder
private struct ProfileImagePlaceholder: View {
    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 120, height: 120)
            .overlay(
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60)
                    .foregroundColor(.gray)
            )
            .overlay(Circle().stroke(Color.mainRed, lineWidth: 2))
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}
