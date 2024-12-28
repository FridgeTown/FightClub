//
//  SignupSeconeView.swift
//  FightClub
//
//  Created by 김지훈 on 26/12/2024.
//
// UI 수정필요

import SwiftUI

struct SignupSecondView: View {
    @ObservedObject var signupData: SignupData
    @Binding var path: [String] // 경로 상태를 바인딩

    @State private var selectedGender: String? = nil
    @State private var isButtonEnabled: Bool = false // 버튼 활성화 상태

    let selectedColor = Color(red: 0.89, green: 0.95, blue: 0.39)
    let unselectedColor = Color.white.opacity(0.09)

    var body: some View {
        ZStack {
            Color(red: 0.14, green: 0.14, blue: 0.14)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("성별을 알려주세요")
                    .font(Font.custom("Poppins", size: 25).weight(.bold))
                    .foregroundColor(.white)
                    .padding(.top, 10)

                ZStack {
                    Rectangle()
                        .fill(Color(red: 0.89, green: 0.07, blue: 0.09))
                        .frame(height: 80)
                    Text("올바른 정보를 입력하셔야만 가장 적합한\n파트너를 찾아서 함께 운동할 수 있습니다!")
                        .font(Font.custom("League Spartan", size: 17).weight(.light))
                        .foregroundColor(selectedColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .padding(.horizontal, 16)
                }
                .padding(.horizontal)

                VStack(spacing: 40) {
                    GenderSelectionButton(
                        title: "Male",
                        symbol: "♂",
                        isSelected: selectedGender == "Male",
                        color: selectedColor
                    ) {
                        selectedGender = "Male"
                        isButtonEnabled = true
                        signupData.gender = "Male"
                    }

                    GenderSelectionButton(
                        title: "Female",
                        symbol: "♀",
                        isSelected: selectedGender == "Female",
                        color: selectedColor
                    ) {
                        selectedGender = "Female"
                        isButtonEnabled = true
                        signupData.gender = "Female"
                    }
                }
                .padding(.top, 8)

                Spacer()

                FCButton("Continue", enabled: $isButtonEnabled) {
                    if let gender = selectedGender {
                        print("Selected Gender: \(gender)")
                        path.append("SignupThirdView") // 다음 화면 경로 추가
                        print("Path after Continue: \(path)") // 디버깅
                    }
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 20)
            }
        }
    }
}
// 성별 선택 버튼
struct GenderSelectionButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSelected ? color : Color.white.opacity(0.09))
                    .frame(width: 160, height: 160)

                Text(symbol)
                    .font(.system(size: 80))
                    .foregroundColor(isSelected ? .black : .white)
            }
            .onTapGesture {
                action()
            }

            Text(title)
                .font(Font.custom("Poppins", size: 20).weight(.bold))
                .foregroundColor(.white)
        }
    }
}

struct SignupSecondView_Previews: PreviewProvider {
    static var previews: some View {
        // 의미 있는 테스트 데이터 생성
        let testSignupData = SignupData()
        testSignupData.gender = "Female" // 초기 테스트 데이터 설정
        
        return SignupSecondView(
            signupData: testSignupData,          // 미리 채운 데이터 전달
            path: .constant(["SignupFirstView"]) // 이전 경로 포함
        )
    }
}
