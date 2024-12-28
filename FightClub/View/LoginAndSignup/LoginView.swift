//
//  LoginView.swift
//  FightClub
//
//  Created by 김지훈 on 26/12/2024.
//

import SwiftUI

struct LoginView: View {
    var body: some View {
        ZStack {
            Color(red: 0.89, green: 0.1, blue: 0.1)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Text("Welcome to FightClub")
                    .font(Font.custom("BebasNeue", size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(0.8), radius: 4, x: 2, y: 2)

                Text("소셜 계정으로 로그인하세요.")
                    .font(Font.custom("League Spartan", size: 16))
                    .foregroundColor(.white)

                VStack(spacing: 20) {
                    FCButton("Google로 로그인") {
                        print("Google 로그인 버튼 탭")
                    }
                    
                    FCButton("Apple ID로 로그인") {
                        print("Apple 로그인 버튼 탭")
                    }
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 40)
                
                Text("아직 회원이 아니신가요?")
                    .font(Font.custom("League Spartan", size: 14).weight(.light))
                    .foregroundColor(.white)
                
                FCButton("회원가입 하기") {
                    print("회원가입 버튼 탭")
                }
                .padding(.horizontal, 40)
            }
            .padding(.top, 80)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
