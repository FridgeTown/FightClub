//
//  SignupSeconeView.swift
//  FightClub
//
//  Created by 김지훈 on 26/12/2024.
//
// UI 수정필요

import SwiftUI

struct SignupSecondView: View {
    @State private var selectedGender: String? = nil
    @State private var navigateToThirdView = false // 상태 추가

    // 선택된 상태일 때 표시할 노란색
    let selectedColor = Color(red: 0.89, green: 0.95, blue: 0.39)
    // 선택되지 않은 상태일 때 표시할 (투명+테두리)
    let unselectedColor = Color.white.opacity(0.09)

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.14, green: 0.14, blue: 0.14)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // 상단 바 제거 (Back 버튼 중복 방지)

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
                        }

                        GenderSelectionButton(
                            title: "Female",
                            symbol: "♀",
                            isSelected: selectedGender == "Female",
                            color: selectedColor
                        ) {
                            selectedGender = "Female"
                        }
                    }
                    .padding(.top, 8)

                    Spacer()

                    // Continue 버튼
                    FCButton("Continue") {
                        // 옵셔널 바인딩
                        guard let gender = selectedGender else {
                            print("성별이 선택되지 않았습니다.")
                            return
                        }
                        
                        // 성별이 존재하면 콘솔에 프린트
                        print("Continue tapped with \(gender)")
                        
                        // 다음 화면 이동
                        navigateToThirdView = true
                    }
                    .padding(.horizontal, 50)
                    .padding(.bottom, 20)
                }
            }
            .navigationDestination(isPresented: $navigateToThirdView) {
                SignupThirdView() // 세 번째 화면으로 이동
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
        SignupSecondView()
    }
}
