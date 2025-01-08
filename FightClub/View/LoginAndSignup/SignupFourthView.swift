//
//  Untitled.swift
//  FightClub
//
//  Created by 김지훈 on 27/12/2024.
//
// 좌우 범위 판정이 어색한 상태
// UI 수정 필요 (눈금 및 바늘침(Polygon) 다시 표현하기)

import SwiftUI

struct SignupFourthView: View {
    @ObservedObject var signupData: SignupData // 상태 전달
    @Binding var path: [String]               // NavigationStack 경로 상태

    @State private var selectedWeight: Float = 75.0 // 내부적으로 kg 단위로 관리
    @State private var isKg: Bool = true           // KG/LB 토글

    // 표시용 프로퍼티: isKg == false면 lb로 환산해서 화면에 보임
    private var displayWeight: Float {
        isKg ? selectedWeight : selectedWeight * 2.20462 // kg -> lb 변환
    }

    var body: some View {
        ZStack {
            // 배경색
            Color(.sRGB, red: 0.14, green: 0.14, blue: 0.14, opacity: 1)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                // 제목
                Text("몸무게가 어떻게 되시나요?")
                    .font(Font.custom("Poppins", size: 35).weight(.bold))
                    .foregroundColor(.white)

                // 설명
                Text("평소 몸무게를 입력하세요. 파이트클럽은 안전을 위해 비슷한 체중의 파트너를 매칭해 드립니다.")
                    .font(Font.custom("League Spartan", size: 14).weight(.light))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.horizontal, 40)

                // KG/LB 토글 버튼
                HStack(spacing: 0) {
                    Button {
                        isKg = true
                    } label: {
                        Text("KG")
                            .font(Font.custom("Poppins", size: 18).weight(.bold))
                            .foregroundColor(isKg ? Color.black : Color.black.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isKg ? Color(red: 0.89, green: 0.95, blue: 0.39) : Color.clear)
                            .cornerRadius(14)
                    }

                    Button {
                        isKg = false
                    } label: {
                        Text("LB")
                            .font(Font.custom("Poppins", size: 18).weight(.bold))
                            .foregroundColor(!isKg ? Color.black : Color.black.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(!isKg ? Color(red: 0.89, green: 0.95, blue: 0.39) : Color.clear)
                            .cornerRadius(14)
                    }
                }
                .frame(width: 200, height: 44)
                .background(Color.white.opacity(0.09))
                .cornerRadius(100)
                .overlay(
                    RoundedRectangle(cornerRadius: 100)
                        .stroke(.white.opacity(0.25), lineWidth: 0.25)
                )
                .padding(.top, 16)

                // 빨간 바 + 눈금
                ZStack {
                    Rectangle()
                        .fill(Color(red: 0.89, green: 0.07, blue: 0.09))
                        .frame(height: 80)

                    WeightScaleView(
                        selectedWeight: $selectedWeight,
                        minWeight: 30.0,
                        maxWeight: 200.0,
                        step: 0.2
                    )
                }
                .frame(height: 80)
                .padding(.top, 16)

                // 현재 선택된 값 표시
                HStack(spacing: 8) {
                    Text(String(format: "%.1f", displayWeight))
                        .font(Font.custom("Poppins", size: 64).weight(.bold))
                        .foregroundColor(.white)
                    Text(isKg ? "Kg" : "Lb")
                        .font(Font.custom("Poppins", size: 24).weight(.bold))
                        .foregroundColor(.white.opacity(0.65))
                        .offset(y: 12)
                }
                .padding(.top, 32)

                Spacer()

                // Continue 버튼 (FCButton 적용)
                FCButton("Continue") {
                    signupData.weight = selectedWeight // 선택된 몸무게를 저장
                    print("Selected Weight: \(signupData.weight ?? 0) KG") // 디버깅
                    path.append("SignupFifthView") // 다음 뷰로 이동
                    print("Path: \(path)") // 디버깅
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(false) // 기본 Back 버튼 유지
    }
}

struct WeightScaleView: View {
    @Binding var selectedWeight: Float
    let minWeight: Float
    let maxWeight: Float
    let step: Float

    private var weightValues: [Float] {
        stride(from: minWeight, through: maxWeight, by: step).map { Float($0) }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                ForEach(weightValues, id: \.self) { weight in
                    let isSelected = weight == selectedWeight
                    Text(String(format: "%.1f", weight))
                        .font(Font.custom("Poppins", size: isSelected ? 20 : 16).weight(.bold))
                        .foregroundColor(isSelected ? .yellow : .white)
                        .onTapGesture {
                            selectedWeight = weight
                        }
                }
            }
            .padding(.horizontal, 40)
        }
        .frame(height: 80)
    }
}

struct SignupFourthView_Previews: PreviewProvider {
    static var previews: some View {
        // 테스트용 SignupData와 Path 생성
        let testSignupData = SignupData() // SignupData 인스턴스 생성
        testSignupData.weight = 75.0      // 초기 데이터 설정 (예: 75kg)

        return SignupFourthView(
            signupData: testSignupData,   // 테스트 데이터 전달
            path: .constant(["SignupThirdView"]) // 초기 Path 설정
        )
    }
}
