//
//  MyProfile.swift
//  FightClub
//
//  Created by 김지훈 on 08/01/2025.
//

import SwiftUI

struct MyProfileView: View {
    @State private var profileData: UserData? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let profile = profileData {
                VStack(spacing: 20) {
                    // 프로필 이미지
                    if let imageUrlString = profile.profileImg,
                       let imageUrl = URL(string: imageUrlString),
                       !imageUrlString.isEmpty {
                        AsyncImage(url: imageUrl) { image in
                            image
                                .resizable()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } placeholder: {
                            Image(systemName: "person.circle")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Image(systemName: "person.circle")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                    }

                    // 사용자 이름
                    Text(profile.nickname ?? "Not found")
                        .font(.title)
                        .bold()

                    // 사용자 소개
                    Text(profile.bio ?? "Not Found")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("성별: \(profile.gender ?? "Not Found")")
                        Text("나이: \(0)")
                        Text("키: \(profile.height ?? 0.0) cm")
                        Text("체중: \(profile.weight ?? 0.0) kg")
                        Text("체급: \(profile.weightClass ?? "Not Found")")
                        Text("포인트: \(profile.points ?? 0)")
                        //Text("심박수: \(profile.heartBeat) bpm")
                        //Text("칼로리 소모량: \(profile.kcal) kcal")
                        //Text("역할: \(profile.role)")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                }
            } else {
                Text(errorMessage ?? "프로필 정보를 불러올 수 없습니다.")
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            loadUserInfo()
        }
        .padding()
        .navigationTitle("내 프로필")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadUserInfo() {
        fetchUserInfo { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let userData):
                    self.profileData = userData
                    self.isLoading = false
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct MyProfileView_Previews: PreviewProvider {
    static var previews: some View {
        MyProfileView()
    }
}
