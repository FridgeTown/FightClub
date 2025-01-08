//
//  SignupThirdView.swift
//  FightClub
//
//  Created by 김지훈 on 27/12/2024.
//

import SwiftUI

struct SignupThirdView: View {
    @ObservedObject var signupData: SignupData
    @Binding var path: [String]

    @State private var selectedAge = 28
    let selectedColor = Color(red: 0.89, green: 0.95, blue: 0.39)

    var body: some View {
        ZStack {
            // 배경 색상
            Color(red: 0.14, green: 0.14, blue: 0.14)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // 헤더 텍스트
                Text("나이가 어떻게 되세요?")
                    .font(Font.custom("Poppins", size: 25).weight(.bold))
                    .foregroundColor(.white)

                // 설명 텍스트
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

                Spacer()

                // 나이 선택 스크롤
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 30) {
                        ForEach(18...70, id: \.self) { age in
                            VStack {
                                Text("\(age)")
                                    .font(Font.custom("Poppins", size: age == selectedAge ? 100 : 65).weight(.bold))
                                    .foregroundColor(age == selectedAge ? .white : .gray)
                                    .scaleEffect(age == selectedAge ? 1.2 : 1.0)

                                if age == selectedAge {
                                    Image(systemName: "triangle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(selectedColor)
                                        .padding(.top, -10)
                                }
                            }
                            .onTapGesture {
                                withAnimation {
                                    selectedAge = age
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 150)

                Spacer()

                // 하단 "Continue" 버튼
                FCButton("Continue") {
                    signupData.age = selectedAge
                    print("Selected Age: \(selectedAge)")
                    path.append("SignupFourthView") // 경로 추가
                    print("Current Path: \(path)") // 디버깅 메시지
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 20)
            }
        }
    }
}

struct SignupThirdView_Previews: PreviewProvider {
    static var previews: some View {
        // 의미 있는 테스트 데이터 생성
        let testSignupData = SignupData()
        testSignupData.gender = "Male"
        testSignupData.age = 25

        return SignupThirdView(
            signupData: testSignupData,          // 미리 채운 데이터 전달
            path: .constant(["SignupSecondView"]) // 이전 경로 포함
        )
    }
}
