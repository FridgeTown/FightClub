import Foundation
import TalkPlus

class AuthService {
    static let shared = AuthService()
    private let tokenManager = TokenManager.shared
    private init() {}
    
    func checkUserExists(email: String, provider: String, token: String) async throws -> Bool {
        let endpoint = APIEndpoint.logIn(email: email, provider: provider, token: token)
        do {
            let response: APIResponse<UserData> = try await NetworkManager.shared.request(endpoint)
            if response.status == 200 {
//                print("---USER DATA 디버그 영역입니다---")
                print("id: ", response.data?.id)
//                print("chatToken: ", response.data?.chatToken)
                print("accessToken: ", response.data?.accessToken)
//                print("nickname: ", response.data?.nickname)
//                print("email: ", response.data?.email)
//                let chatid = String(response.data.id!)
//                print("---USER DATA 디버그 끝---")
//                let params = TPLoginParams(loginType: TPLoginType.token, userId: String(response.data.id!))
//                params?.loginToken = loginToken
//                params?.userName = userName
//                params?.profileImageUrl = profileImageUrl
//                params?.metaData = metaData
//                params?.translationLanguage = translationLanguage
//
//                TalkPlus.sharedInstance()?.login(params,success: { tpUser in
//                    // SUCCESS
//                }, failure: { [weak self] (errorCode, error) in
//                    // FAILURE
//                })
                if let token = response.data?.accessToken {
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
    
    func validateToken() async throws -> Bool {
            let endPoint = APIEndpoint.getUserInfo
            
            do {
                let response: APIResponse<UserData> = try await NetworkManager.shared.request(endPoint)
                switch response.status {
                case 200:
                    //싱글톤 패턴. 유저 정보 저장하기
                    let token = try? TokenManager.shared.getAccessToken()
                    print("ACCESS TOKEN: ", token)
                    return true
                case 401:  // 토큰이 유효하지 않은 경우
                    throw AuthError.invalidCredentials
                case 403:  // 권한이 없는 경우
                    throw AuthError.unauthorized
                default:
                    throw AuthError.networkError
                }
            } catch let error as AuthError {
                throw error
            } catch {
                print("토큰 검증 실패: \(error.localizedDescription)")
                throw AuthError.networkError
            }
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
    case unauthorized
    
    var errorDescription: String {
        switch self {
        case .invalidCredentials:
            return "인증 정보가 유효하지 않습니다"
        case .noRefreshToken:
            return "리프레시 토큰이 없습니다"
        case .networkError:
            return "네트워크 오류가 발생했습니다"
        case .unauthorized:
            return "접근 권한이 없습니다"
        case .unknown:
            return "알 수 없는 오류가 발생했습니다"
        }
    }
}
