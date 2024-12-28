//
//  Registration.swift
//  FightClub
//
//  Created by 김지훈 on 26/12/2024.
//
//
//  SignupFirstView.swift
//  FightClub
//
//

import SwiftUI

struct SignupFirstView: View {
    @State private var navigateToSecondView = false // 상태 추가

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.89, green: 0.1, blue: 0.1)
                    .ignoresSafeArea()

                GeometryReader { geometry in
                    VStack(spacing: 20) {
                        Image("furyusyk")
                            .resizable()
                            .scaledToFill()
                            .ignoresSafeArea(edges: .all)
                            .frame(width: geometry.size.width, height: geometry.size.height * 0.5)
                            .clipped()
                        
                        Spacer()

                        Text("실력과 체급에 맞춰서\n안전하게 훈련하세요\n언제나 안전이 최우선입니다")
                            .font(Font.custom("Poppins", size: 24).weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(red: 0.7, green: 1, blue: 0.9))
                            .lineSpacing(10)
                            .padding(.horizontal, 16)

                        Spacer()

                        Link("자세한 약관은 이곳을 클릭해주세요", destination: URL(string: "https://www.example.com/terms")!)
                            .font(Font.custom("League Spartan", size: 14).weight(.light))
                            .foregroundColor(.white)

                        FCButton("Next") {
                            navigateToSecondView = true // 버튼 동작으로 화면 전환
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToSecondView) {
                SignupSecondView() // 두 번째 화면으로 이동
            }
        }
    }
}

// 미리보기
struct SignupFirstView_Previews: PreviewProvider {
    static var previews: some View {
        SignupFirstView()
    }
}
