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
            Button("확인", role: .cancel) {}
        } message: {
            Text("프로필 데이터가 성공적으로 저장되었습니다.")
        }
        .alert("오류", isPresented: $showErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // onAppear에서 데이터 확인
            print("ProfileView appeared with email: \(signupData.email ?? "nil")")
        }
    }

    // MARK: - 서버로 프로필 데이터 전송
    /*
    private func submitProfileData() {
        guard !nickname.isEmpty else {
            errorMessage = "닉네임을 입력하세요."
            showErrorAlert = true
            return
        }

        isSubmitting = true

        // UserDefaults에서 idToken 가져오기
        let idToken = UserDefaults.standard.string(forKey: "idToken") ?? ""
        print("ProfileView에서 불러온 idToken: \(idToken)")

        guard !idToken.isEmpty else {
            errorMessage = "로그인이 만료되었습니다. 다시 로그인해주세요."
            showErrorAlert = true
            isSubmitting = false
            return
        }

        // APIEndpoint 사용
        guard let email = signupData.email, !email.isEmpty else {
            errorMessage = "이메일 정보가 없습니다. 다시 로그인해주세요."
            showErrorAlert = true
            isSubmitting = false
            return
        }

        let registerEndpoint = APIEndpoint.register(email: "example@gmail.com", provider: "google", token: "sample_token")
        AF.request(
            registerEndpoint.url,
            method: registerEndpoint.method,
            parameters: registerEndpoint.parameters,
            encoding: JSONEncoding.default
        ).response { response in
            print(response)
        }

        // Alamofire 요청
        AF.request(apiEndpoint.url, method: apiEndpoint.method, parameters: apiEndpoint.parameters, encoding: JSONEncoding.default)
            .validate()
            .response { response in
                self.isSubmitting = false

                switch response.result {
                case .success:
                    print("프로필 데이터 전송 성공")
                    self.showSuccessAlert = true

                case .failure(let error):
                    print("프로필 데이터 전송 실패: \(error.localizedDescription)")
                    if let statusCode = response.response?.statusCode {
                        print("HTTP 상태 코드: \(statusCode)")
                    }
                    self.errorMessage = "프로필 데이터 저장 중 오류가 발생했습니다."
                    self.showErrorAlert = true
                }
            }
    }*/
    
    private func submitProfileData() {
        guard !nickname.isEmpty else {
            errorMessage = "닉네임을 입력하세요."
            showErrorAlert = true
            return
        }

        isSubmitting = true

        // UserDefaults에서 idToken 가져오기
        let idToken = UserDefaults.standard.string(forKey: "idToken") ?? ""
        print("ProfileView에서 불러온 idToken: \(idToken)")

        guard !idToken.isEmpty else {
            errorMessage = "로그인이 만료되었습니다. 다시 로그인해주세요."
            showErrorAlert = true
            isSubmitting = false
            return
        }

        // APIEndpoint 사용
        guard let email = signupData.email, !email.isEmpty else {
            errorMessage = "이메일 정보가 없습니다. 다시 로그인해주세요."
            showErrorAlert = true
            isSubmitting = false
            return
        }

        // 요청 데이터 구성
        let parameters: [String: Any] = [
            "email": email,
            "provider": "google",
            "profileImage": "", // 기본값 하드코딩
            "gender": signupData.gender ?? "MALE", // 기본값 하드코딩
            "age": signupData.age ?? 0, // 없으면 기본값 0
            "weight": signupData.weight ?? 0.0, // 없으면 기본값 0.0
            "height": signupData.height ?? 0.0, // 없으면 기본값 0.0
            "bio": "기본 bio", // 기본값 하드코딩
            "weightClass": "FLY", // 기본값 하드코딩
            "role": "ROLE_USER", // 기본값 하드코딩
            "nickname": nickname, // 사용자가 입력한 닉네임
            "idToken": idToken // UserDefaults에서 가져온 idToken
        ]

        // 디버깅 로그 추가
        print("Sending to URL: http://3.34.46.87:8080/signup")
        print("Parameters: \(parameters)")

        // Alamofire 요청
        AF.request(
            "http://3.34.46.87:8080/signup",
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default
        )
        .responseJSON { response in
            self.isSubmitting = false

            switch response.result {
            case .success(let value):
                // value는 Any 타입이므로 [String: Any]로 캐스팅 가능
                if let data = value as? [String: Any],
                   let accessToken = data["accessToken"] as? String {
                    
                    // Access Token을 UserDefaults에 저장
                    UserDefaults.standard.setValue(accessToken, forKey: "accessToken")
                    UserDefaults.standard.synchronize()
                    
                    // 이후 로직
                    self.showSuccessAlert = true
                } else {
                    self.errorMessage = "Access Token이 존재하지 않습니다."
                    self.showErrorAlert = true
                }
                
            case .failure(let error):
                self.errorMessage = "네트워크 요청 중 오류가 발생했습니다: \(error.localizedDescription)"
                self.showErrorAlert = true
            }
        }
        .validate()
        .response { response in
            self.isSubmitting = false

            // 서버 응답(Response)에서 받아온 JSON 예시
            // 예시: {"accessToken": "...", "refreshToken": "..."}
            switch response.result {
            case .success(let value):
                if let data = value as? [String: Any],
                   let accessToken = data["accessToken"] as? String {
                    
                    // Access Token을 UserDefaults에 저장
                    UserDefaults.standard.setValue(accessToken, forKey: "accessToken")
                    UserDefaults.standard.synchronize()
                    
                    // 이후 로직(성공 Alert 노출, 화면 전환 등)
                    self.showSuccessAlert = true
                } else {
                    // 토큰이 없으면 에러 처리
                    self.errorMessage = "Access Token이 존재하지 않습니다."
                    self.showErrorAlert = true
                }
                
            case .failure(let error):
                // 에러 처리
                self.errorMessage = "네트워크 요청 중 오류가 발생했습니다: \(error.localizedDescription)"
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
