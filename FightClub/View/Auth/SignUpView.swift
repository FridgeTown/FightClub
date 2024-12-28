import SwiftUI

struct SignUpView: View {
    let email: String
    @StateObject private var viewModel = SignUpViewModel()
    @State private var showMainView = false
    
    var body: some View {
        VStack(spacing: 25) {
            Text("프로필 설정")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.mainRed)
            
            VStack(spacing: 20) {
                // 닉네임 입력
                VStack(alignment: .leading, spacing: 8) {
                    Text("닉네임")
                        .font(.headline)
                    TextField("닉네임을 입력해주세요", text: $viewModel.nickname)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // 체급 선택
                VStack(alignment: .leading, spacing: 8) {
                    Text("체급")
                        .font(.headline)
                    Picker("체급", selection: $viewModel.weightClass) {
                        ForEach(WeightClass.allCases, id: \.self) { weightClass in
                            Text(weightClass.rawValue).tag(weightClass)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // 신장 입력
                VStack(alignment: .leading, spacing: 8) {
                    Text("신장")
                        .font(.headline)
                    TextField("키를 입력해주세요 (cm)", text: $viewModel.height)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                }
                
                // 자기소개
                VStack(alignment: .leading, spacing: 8) {
                    Text("자기소개")
                        .font(.headline)
                    TextEditor(text: $viewModel.bio)
                        .frame(height: 100)
                        .padding(4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 회원가입 버튼
            Button(action: {
                Task {
                    await viewModel.signUp(email: email)
                }
            }) {
                Text("회원가입")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.mainRed)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 30)
            .disabled(!viewModel.isValid)
        }
        .padding()
        .navigationDestination(isPresented: $viewModel.isSignUpComplete) {
            HomeView()
        }
    }
}

class SignUpViewModel: ObservableObject {
    @Published var nickname = ""
    @Published var weightClass: WeightClass = .lightweight
    @Published var height = ""
    @Published var bio = ""
    @Published var isSignUpComplete = false
    
    private let authService = AuthService.shared
    
    var isValid: Bool {
        !nickname.isEmpty && !height.isEmpty && !bio.isEmpty
    }
    
    func signUp(email: String) async {
        do {
            let userData = UserSignUpData(
                email: email,
                nickname: nickname,
                weightClass: weightClass,
                height: Int(height) ?? 0,
                bio: bio
            )
            
            try await authService.signUp(userData: userData)
            
            await MainActor.run {
                isSignUpComplete = true
            }
        } catch {
            print("회원가입 실패: \(error.localizedDescription)")
        }
    }
}

enum WeightClass: String, CaseIterable {
    case flyweight = "플라이급"
    case bantamweight = "밴텀급"
    case featherweight = "페더급"
    case lightweight = "라이트급"
    case welterweight = "웰터급"
    case middleweight = "미들급"
    case lightheavyweight = "라이트헤비급"
    case heavyweight = "헤비급"
}

struct UserSignUpData {
    let email: String
    let nickname: String
    let weightClass: WeightClass
    let height: Int
    let bio: String
} 