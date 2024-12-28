//
//  ProfileView.swift
//  FightClub
//
//  Created by 김지훈 on 28/12/2024.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var signupData: SignupData
    @State private var nickname: String = "" // 닉네임 입력 상태

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
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 16)

                // 닉네임 입력 필드
                FCTextField(
                    "닉네임을 입력하세요",
                    text: $nickname,
                    keyboardType: .default,
                    isSecure: false
                )
                .padding(.horizontal, 16)

                Spacer()

                // 완료 버튼
                FCButton("Complete") {
                    signupData.nickname = nickname // 닉네임 저장
                    print("Profile Data: \(signupData.toDictionary())") // 디버깅용 출력

                    // 백엔드로 데이터를 전송하는 로직 추가 가능
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 32)
            }
            .padding()
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let testSignupData = SignupData()
        testSignupData.gender = "Male"
        testSignupData.age = 25
        testSignupData.weight = 75.0
        testSignupData.height = 180.0

        return ProfileView(signupData: testSignupData)
    }
}
