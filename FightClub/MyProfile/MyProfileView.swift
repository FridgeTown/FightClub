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

struct MyProfileView: View {
    @StateObject private var viewModel = MyProfileViewModel()
    @State private var showSplashView = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ProfileMainContent(
                viewModel: viewModel,
                selectedImage: $selectedImage,
                showSplashView: $showSplashView
            )
        }
        .onAppear {
            Task {
                await viewModel.loadUserInfo()
            }
        }
    }
}

struct ProfileMainContent: View {
    @ObservedObject var viewModel: MyProfileViewModel
    @Binding var selectedImage: UIImage?
    @Binding var showSplashView: Bool
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                LoadingView()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ProfileImageSection(viewModel: viewModel, selectedImage: $selectedImage)
                        ProfileInfoSection(viewModel: viewModel)
                        LogoutButton(viewModel: viewModel, showSplashView: $showSplashView)
                    }
                    .padding()
                }
            }
        }
        .alert("로그아웃", isPresented: .init(
            get: { viewModel.showLogoutAlert },
            set: { viewModel.showLogoutAlert = $0 }
        )) {
            LogoutAlertButtons(viewModel: viewModel, showSplashView: $showSplashView)
        } message: {
            Text("정말 로그아웃 하시겠습니까?")
        }
        .alert("업데이트 완료", isPresented: .init(
            get: { viewModel.showSuccessMessage },
            set: { viewModel.showSuccessMessage = $0 }
        )) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("프로필 정보가 성공적으로 업데이트 되었습니다.")
        }
        .onChange(of: selectedImage) { image in
            if let image = image {
                Task {
                    await viewModel.updateProfileImage(image)
                }
            }
        }
        .fullScreenCover(isPresented: $showSplashView) {
            SplashView()
        }
        .navigationTitle("내 프로필")
        .navigationBarTitleDisplayMode(.inline)
    }
}

//// MARK: - Supporting Views
//struct LoadingView: View {
//    var body: some View {
//        ProgressView("Loading...")
//            .tint(Color.mainRed)
//    }
//}

struct ErrorView: View {
    let message: String?
    
    var body: some View {
        Text(message ?? "프로필 정보를 불러올 수 없습니다.")
            .foregroundColor(.red)
    }
}

@MainActor
struct LogoutAlertButtons: View {
    @ObservedObject var viewModel: MyProfileViewModel
    @Binding var showSplashView: Bool
    
    var body: some View {
        Button("취소", role: .cancel) { }
        Button("로그아웃", role: .destructive) {
            Task {
                await viewModel.logout()
                showSplashView = true
            }
        }
    }
}

struct ProfileImageSection: View {
    @ObservedObject var viewModel: MyProfileViewModel
    @Binding var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                ProfileImageView(
                    imageUrl: viewModel.profileData?.profileImg,
                    selectedImage: selectedImage
                )
                
                Button(action: {
                    showImagePicker = true
                }) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.mainRed)
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        )
                }
                .offset(x: 5, y: 5)
            }
            
            if let nickname = viewModel.profileData?.nickname {
                Text(nickname)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.top, 20)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }
}

struct ProfileImageView: View {
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

struct ProfileImagePlaceholder: View {
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
    }
}

struct ProfileInfoSection: View {
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

struct ProfileBodyInfoRow: View {
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

struct LogoutButton: View {
    let viewModel: MyProfileViewModel
    @Binding var showSplashView: Bool
    
    var body: some View {
        Button(action: {
            viewModel.showLogoutAlert = true
        }) {
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

struct ProfileInfoRow: View {
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
