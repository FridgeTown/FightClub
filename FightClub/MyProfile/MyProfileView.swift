//
//  MyProfile.swift
//  FightClub
//
//  Created by 김지훈 on 08/01/2025.
//

import SwiftUI
import PhotosUI
import Alamofire

struct MyProfileView: View {
    @State private var profileData: UserData? = nil
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var isUpdatingImage = false
    @State private var showSuccessMessage = false
    // Alert 제어용 State
    @State private var showLogoutAlert = false
    // SplashView를 fullScreenCover로 띄울 때 쓰일 State
    @State private var showSplashView = false
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let profile = profileData {
                VStack(spacing: 20) {
                    
                    // 프로필 이미지 렌더링
                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else if let imageUrlString = profile.profileImg,
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
                    
                    // 이미지 변경 버튼
                    Button(action: {
                        showImagePicker = true
                    }) {
                        Text("프로필 이미지 변경")
                            .foregroundColor(.blue)
                    }
                    
                    // 사용자 이름 및 추가 정보
                    Text(profile.nickname ?? "Not found")
                        .font(.title)
                        .bold()
                    
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
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // ------------ 로그아웃 버튼 추가 ------------
                    Button(action: {
                        // Alert를 표시하도록
                        showLogoutAlert = true
                    }) {
                        Text("로그아웃")
                            .foregroundColor(.red)
                    }
                    .padding(.top, 8)
                    .alert("로그아웃 하시겠습니까?", isPresented: $showLogoutAlert) {
                        Button("확인", role: .destructive) {
                            logout()
                        }
                        Button("취소", role: .cancel) { }
                    }
                    
                    Spacer()
                }
                .alert(isPresented: $showSuccessMessage) {
                    Alert(
                        title: Text("업데이트 완료"),
                        message: Text("프로필 이미지가 성공적으로 업데이트 되었습니다."),
                        dismissButton: .default(Text("확인"))
                    )
                }
            } else {
                Text(errorMessage ?? "프로필 정보를 불러올 수 없습니다.")
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            loadUserInfo()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { image in
            guard let image = image else { return }
            print("선택된 이미지: \(image)")
            updateProfileImage(image: image) { result in
                switch result {
                case .success:
                    print("프로필 이미지 업로드 성공")
                    self.showSuccessMessage = true
                    loadUserInfo() // 최신 프로필 데이터 다시 가져오기
                case .failure(let error):
                    print("프로필 이미지 업로드 실패: \(error)")
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        .fullScreenCover(isPresented: $showSplashView) {
                    SplashView()
                }
        .padding()
        .navigationTitle("내 프로필")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 로그아웃 로직
    private func logout() {
        do {
            // TokenManager를 통해 로컬 토큰 삭제
            try TokenManager.shared.clearAllTokens()
            showSplashView = true // SplashView 표시
            print("로그아웃: 토큰 삭제 완료")
            // 여기서 혹은 상위 View에서,
            // SplashView로 돌아가는 로직을 추가할 수도 있습니다.
        } catch {
            print("토큰 삭제 실패:", error)
            self.errorMessage = "로그아웃 실패: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 유저 정보 로드
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

    // MARK: - 프로필 이미지 업데이트
    private func updateProfileImage(
        image: UIImage,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let url = URL(string: "http://3.34.46.87:8080/user/image") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        let accessToken: String
        do {
            accessToken = try TokenManager.shared.getAccessToken() ?? ""
        } catch {
            print("Access Token 가져오기 실패: \(error)")
            completion(.failure(error))
            return
        }

        guard !accessToken.isEmpty else {
            print("Access Token이 없습니다.")
            completion(.failure(URLError(.userAuthenticationRequired)))
            return
        }

        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(accessToken)",
            "Content-Type": "multipart/form-data"
        ]

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("이미지 변환 실패")
            completion(.failure(URLError(.cannotCreateFile)))
            return
        }
        print("변환된 이미지 데이터 크기: \(imageData.count) 바이트")

        AF.upload(multipartFormData: { formData in
            formData.append(imageData, withName: "file", fileName: "profile.jpg", mimeType: "image/jpeg")
        }, to: url, method: .post, headers: headers)
        .validate(statusCode: 200..<300)
        .responseDecodable(of: APIResponse<UserData?>.self) { response in
            if let data = response.data, let responseString = String(data: data, encoding: .utf8) {
                print("서버 응답 데이터: \(responseString)")
            } else {
                print("서버 응답 없음")
            }

            if let statusCode = response.response?.statusCode {
                print("HTTP 상태 코드: \(statusCode)")
            }

            switch response.result {
            case .success(let apiResponse):
                print("응답 성공: \(apiResponse)")
                DispatchQueue.main.async {
                    self.showSuccessMessage = true
                    completion(.success(()))
                }
            case .failure(let error):
                print("업로드 실패: \(error)")
                completion(.failure(error))
            }
        }
    }
}

struct MyProfileView_Previews: PreviewProvider {
    static var previews: some View {
        MyProfileView()
    }
}
