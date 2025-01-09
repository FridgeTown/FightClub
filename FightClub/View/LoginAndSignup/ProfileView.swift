//
//  ProfileView.swift
//  FightClub
//
//  Created by 김지훈 on 28/12/2024.
//

import SwiftUI
import Alamofire

struct ProfileView: View {
    @ObservedObject var signupData: SignupData
    @State private var navigateToSplashView = false
    @State private var nickname: String = "" // 닉네임 입력 상태
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false

    var body: some View {
        ZStack {
            Color(.sRGB, red: 0.14, green: 0.14, blue: 0.14, opacity: 1)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("프로필 설정")
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)

                // 이전 입력 정보 표시
                VStack(alignment: .leading, spacing: 10) {
                    Text("입력된 정보")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.white)

                    HStack {
                        Text("성별: ")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(signupData.gender ?? "N/A")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    HStack {
                        Text("나이: ")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(signupData.age ?? 0)")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    HStack {
                        Text("몸무게: ")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(String(format: "%.1f kg", signupData.weight ?? 0.0))
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    HStack {
                        Text("키: ")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(String(format: "%.1f cm", signupData.height ?? 0.0))
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    HStack {
                        Text("이메일: ")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(signupData.email ?? "N/A") // 이메일 추가
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 16)

                // 닉네임 입력 필드
                TextField("닉네임을 입력하세요", text: $nickname)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 16)
                    .foregroundColor(.white)

                // 완료 버튼
                Button(action: {
                    signupData.nickname = nickname // 닉네임 저장
                    print("Submitting data: \(signupData.email ?? "nil")") // 디버깅 로그
                    submitProfileData()
                }) {
                    Text("Complete")
                        .bold()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 50)
                .disabled(isSubmitting)
            }
            .padding()
        }
        .alert("성공", isPresented: $showSuccessAlert) {
            Button("확인") {
                navigateToSplashView = true // SplashView로 이동 트리거
            }
        } message: {
            Text("프로필 데이터가 성공적으로 저장되었습니다.")
        }
        .alert("오류", isPresented: $showErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $navigateToSplashView) {
            SplashView()
                .onAppear {
                    print("SplashView appeared!")
                }
        }
        .onAppear {
            // onAppear에서 데이터 확인
            print("ProfileView appeared with email: \(signupData.email ?? "nil")")
        }
    }
    
    private func submitProfileData() {
        guard !nickname.isEmpty else {
            errorMessage = "닉네임을 입력하세요."
            showErrorAlert = true
            return
        }

        isSubmitting = true

        // UserDefaults에서 idToken 가져오기
        let idToken = UserDefaults.standard.string(forKey: "idToken") ?? ""
        guard !idToken.isEmpty else {
            errorMessage = "로그인이 만료되었습니다. 다시 로그인해주세요."
            showErrorAlert = true
            isSubmitting = false
            return
        }

        guard let email = signupData.email, !email.isEmpty else {
            errorMessage = "이메일 정보가 없습니다. 다시 로그인해주세요."
            showErrorAlert = true
            isSubmitting = false
            return
        }

        let parameters: [String: Any] = [
            "email": email,
            "provider": "google",
            "profileImage": "",
            "gender": signupData.gender ?? "MALE",
            "age": signupData.age ?? 0,
            "weight": signupData.weight ?? 0.0,
            "height": signupData.height ?? 0.0,
            "bio": "자기소개를 입력해보세요",
            "weightClass": "FLY",
            "role": "ROLE_USER",
            "nickname": nickname,
            "idToken": idToken
        ]

        AF.request(
            "http://3.34.46.87:8080/signup",
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default
        )
        .validate()
        .responseDecodable(of: APIResponse<UserData>.self) { response in
            self.isSubmitting = false
            switch response.result {
            case .success(let apiResponse):
                guard let userData = apiResponse.data else {
                    self.errorMessage = "유효하지 않은 응답입니다."
                    self.showErrorAlert = true
                    return
                }
                guard let accessToken = userData.accessToken else {
                    self.errorMessage = "유효하지 않은 Access Token입니다."
                    self.showErrorAlert = true
                    return
                }
                
                do {
                    try TokenManager.shared.saveAccessToken(accessToken)
                    self.showSuccessAlert = true
                } catch {
                    self.errorMessage = "토큰 저장 중 오류가 발생했습니다: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
                
            case .failure(let error):
                print("네트워크 요청 실패: \(error.localizedDescription)")
                self.errorMessage = "프로필 데이터 저장 중 오류가 발생했습니다."
                self.showErrorAlert = true
            }
        }
    }
}

// MARK: - Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let testSignupData = SignupData()
        testSignupData.gender = "Male"
        testSignupData.age = 25
        testSignupData.weight = 70.0
        testSignupData.height = 180.0
        testSignupData.email = "test@example.com" // 테스트용 이메일 추가

        return ProfileView(signupData: testSignupData)
    }
}
