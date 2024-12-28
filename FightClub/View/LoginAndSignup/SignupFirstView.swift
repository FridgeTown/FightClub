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

class SignupData: ObservableObject {
    @Published var gender: String? = nil
    @Published var age: Int? = nil
    @Published var weight: Float? = nil
    @Published var height: Float? = nil
    @Published var nickname: String? = nil

    func toDictionary() -> [String: Any] {
        return [
            "gender": gender ?? "",
            "age": age ?? 0,
            "weight": weight ?? 0.0,
            "height": height ?? 0.0,
            "nickname": nickname ?? ""
        ]
    }
}

struct SignupFirstView: View {
    @State private var path: [String] = [] // 경로 상태 추가
    @StateObject var signupData = SignupData()

    var body: some View {
        NavigationStack(path: $path) { // path를 NavigationStack에 바인딩
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
                            path.append("SignupSecondView") // 경로를 추가하여 화면 전환
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { view in
                switch view {
                case "SignupSecondView":
                    SignupSecondView(signupData: signupData, path: $path)
                case "SignupThirdView":
                    SignupThirdView(signupData: signupData, path: $path)
                case "SignupFourthView":
                    SignupFourthView(signupData: signupData, path: $path)
                case "SignupFifthView":
                    SignupFifthView(signupData: signupData, path: $path)
                case "ProfileView":
                    ProfileView(signupData: signupData)
                default:
                    EmptyView()
                }
            }
        }
    }
}

// 미리보기
struct SignupFirstView_Previews: PreviewProvider {
    static var previews: some View {
        SignupFirstView()
            .environmentObject(SignupData()) // 미리보기 환경에서 SignupData 주입
    }
}
