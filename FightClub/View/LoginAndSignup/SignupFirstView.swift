//  SignupFirstView.swift
//  FightClub
//
// 우선 Google 로그인을 기준으로 구현

import SwiftUI

struct SignupFirstView: View {
    @Binding var path: [String] // 상위에서 경로를 바인딩 받도록 수정
    @ObservedObject var signupData: SignupData // 상위에서 전달받은 SignupData 사용
    @ObservedObject var googleAuthViewModel: GoogleOAuthViewModel // 상위에서 전달받은 ViewModel 사용

    var body: some View {
        NavigationStack(path: $path) {
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
                            // 더 이상 googleAuthViewModel.givenEmail을 확인하지 않음
                            if let email = signupData.email, !email.isEmpty {
                                print("Proceeding to SignupSecondView with email: \(email)")
                                path.append("SignupSecondView")
                            } else {
                                print("Error: signupData.email is nil or empty")
                            }
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .onAppear {
                print("SignupFirstView - onAppear - googleAuthViewModel.givenEmail: \(googleAuthViewModel.givenEmail ?? "N/A")")
                print("SignupFirstView - ViewModel Instance: \(Unmanaged.passUnretained(googleAuthViewModel).toOpaque())")
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
    @State static var path: [String] = [] // Dummy path for Preview
    static var previews: some View {
        SignupFirstView(
            path: $path, // Provide the dummy path
            signupData: SignupData(), // Provide a dummy SignupData instance
            googleAuthViewModel: GoogleOAuthViewModel() // Provide a dummy GoogleOAuthViewModel instance
        )
    }
}
