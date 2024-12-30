import Foundation

class AuthService {
    static let shared = AuthService()
    private let tokenManager = TokenManager.shared
    private init() {}
    
    func checkUserExists(email: String, provider: String, token: String) async throws -> Bool {
        let endpoint = APIEndpoint.logIn(email: email, provider: provider, token: token)
        do {
            let response: APIResponse<UserData> = try await NetworkManager.shared.request(endpoint)
            if response.status == 200 {
                if let token = response.data?.accessToken {
                    print(token)
                    try tokenManager.saveAccessToken(token)
                }
                return true
            } else {
                return false
            }
        } catch {
            throw AuthError.networkError
        }
    }
    
//    func signUp(userData: UserSignUpData) async throws {
        // TODO: API 구현
        // let response = try await NetworkManager.shared.request(
        //     .signUp(userData: userData)
        // )
        // try tokenManager.saveAccessToken(response.token)
//    }
    
    func validateToken(_ token: String) async throws -> Bool {
        // TODO: API 구현
        // let response = try await NetworkManager.shared.request(
        //     .validateToken(token: token)
        // )
        // return response.isValid
        return true
    }
    
    func refreshToken() async throws {
        // TODO: API 구현
        // guard let refreshToken = try tokenManager.getRefreshToken() else {
        //     throw AuthError.noRefreshToken
        // }
        // let response = try await NetworkManager.shared.request(
        //     .refreshToken(token: refreshToken)
        // )
        // try tokenManager.saveAccessToken(response.accessToken)
        // if let newRefreshToken = response.refreshToken {
        //     try tokenManager.saveRefreshToken(newRefreshToken)
        // }
    }
}

enum AuthError: Error {
    case invalidCredentials
    case noRefreshToken
    case networkError
    case unknown
} 
