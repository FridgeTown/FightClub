//
//  SignupFifthView.swift
//  FightClub
//
//  Created by 김지훈 on 28/12/2024.
//
// 여기도 마찬가지로 UI 수정필요.
// 위아래 범위 판정이 어색한 상태
// 여유있으면 Ft, In 단위로도

import SwiftUI

struct SignupFifthView: View {
    @State private var selectedHeight: Float = 180.0 // 선택된 키 (기본값)
    let minHeight: Float = 100.0 // 최소 키
    let maxHeight: Float = 250.0 // 최대 키
    let step: Float = 0.5 // 조정 단위

    var body: some View {
        NavigationStack {
            ZStack {
                // 배경색
                Color(.sRGB, red: 0.14, green: 0.14, blue: 0.14, opacity: 1)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()
                    // 제목 (텍스트 위치 조정)
                    Text("키가 어떻게 되시나요?")
                        .font(Font.custom("Poppins", size: 35).weight(.bold))
                        .foregroundColor(.white)

                    // 자꾸만 
                    Text("이제 거의 다 끝났습니다.\n 즐거운 스파링 시간을 준비하세요!")
                        .font(Font.custom("League Spartan", size: 14).weight(.light))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center) // 텍스트 중앙 정렬
                        .lineLimit(nil) // 줄 수 제한 해제
                        .lineSpacing(8) // 줄 간격 조정
                        .frame(maxWidth: .infinity) // 가로 공간 확보
                        .padding(.horizontal, 40) // 좌우 여백 설정
                        .fixedSize(horizontal: false, vertical: true) // 세로 공간을 자동으로 확장

                    // 빨간 바 + 눈금 (수직 스크롤)
                    ZStack {
                        Rectangle()
                            .fill(Color(red: 0.89, green: 0.07, blue: 0.09))
                            .frame(width: 80)

                        HeightScaleView(
                            selectedHeight: $selectedHeight,
                            minHeight: minHeight,
                            maxHeight: maxHeight,
                            step: step
                        )
                    }
                    .frame(width: 80, height: 400)
                    .padding(.top, 16)

                    // 현재 선택된 값 표시
                    HStack(spacing: 8) {
                        Text(String(format: "%.1f", selectedHeight))
                            .font(Font.custom("Poppins", size: 64).weight(.bold))
                            .foregroundColor(.white)
                        Text("cm")
                            .font(Font.custom("Poppins", size: 24).weight(.bold))
                            .foregroundColor(.white.opacity(0.65))
                            .offset(y: 12)
                    }
                    .padding(.top, 32)

                    Spacer()

                    // Continue 버튼 (FCButton 적용)
                    FCButton("Continue") {
                        print("Continue tapped with height \(selectedHeight) cm")
                    }
                    .padding(.horizontal, 50)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarBackButtonHidden(false) // 기본 Back 버튼 유지
        }
    }
}
// 수직 스크롤로 키 조절 구현
struct HeightScaleView: View {
    @Binding var selectedHeight: Float
    let minHeight: Float
    let maxHeight: Float
    let step: Float

    private var heightValues: [Float] {
        stride(from: minHeight, through: maxHeight, by: step).map { Float($0) }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                ForEach(heightValues, id: \.self) { height in
                    let isSelected = height == selectedHeight
                    Text(String(format: "%.1f", height))
                        .font(Font.custom("Poppins", size: isSelected ? 20 : 16).weight(.bold))
                        .foregroundColor(isSelected ? .yellow : .white.opacity(0.5))
                        .scaleEffect(isSelected ? 1.2 : 1.0)
                        .onTapGesture {
                            selectedHeight = height
                        }
                }
            }
            .padding(.vertical, 40)
        }
    }
}

struct SignupFifthView_Previews: PreviewProvider {
    static var previews: some View {
        SignupFifthView()
    }
}
