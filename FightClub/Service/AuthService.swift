import Foundation
import TalkPlus

class AuthService {
    static let shared = AuthService()
    private let tokenManager = TokenManager.shared
    private let userDataManager = UserDataManager.shared
    private init() {}
    
    func checkUserExists(email: String, provider: String, token: String) async throws -> Bool {
        let endpoint = APIEndpoint.logIn(email: email, provider: provider, token: token)
        do {
            let response: APIResponse<UserData> = try await NetworkManager.shared.request(endpoint)
            if response.status == 200 {
                if let user = response.data {
                    userDataManager.setUserData(user)
                    let params = TPLoginParams(loginType: TPLoginType.token, userId: user.id.toString())
                    params?.loginToken = user.chatToken
                    params?.userName = user.nickname
    
                    TalkPlus.sharedInstance()?.login(params,success: { tpUser in
                        // SUCCESS
                        print("채팅 login 성공 ! ")
                        // 로그인 성공 노티피케이션 발송
                                            DispatchQueue.main.async {
                                                NotificationCenter.default.post(name: Notification.Name("UserDidLogin"), object: nil)
                                            }
                        TalkPlus.sharedInstance().enablePushNotification { tpUser in
                            print("enablePushNotification")
                        } failure: { (errorCode, error) in }
                    }, failure: { [weak self] (errorCode, error) in
                        // FAILURE
                        print("채팅 errorCode: \(errorCode)", "채팅 error: \(error?.localizedDescription)")
                    })
                    
                }
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
                    if let user = response.data {
                        userDataManager.setUserData(user)
                        print("유저 데이터", user)
                        print("ACCESS TOKEN", try TokenManager.shared.getAccessToken())
                        let params = TPLoginParams(loginType: TPLoginType.token, userId: user.id.toString())
                        params?.loginToken = user.chatToken
                        params?.userName = user.nickname
        
                        TalkPlus.sharedInstance()?.login(params,success: { tpUser in
                            // SUCCESS
                            print("채팅 login 성공 ! ")
                            // 로그인 성공 노티피케이션 발송
                                                DispatchQueue.main.async {
                                                    NotificationCenter.default.post(name: Notification.Name("UserDidLogin"), object: nil)
                                                }
                            TalkPlus.sharedInstance().enablePushNotification { tpUser in
                                print("enablePushNotification")
                            } failure: { (errorCode, error) in }
                        }, failure: { [weak self] (errorCode, error) in
                            // FAILURE
                            print("채팅 errorCode: \(errorCode)", "채팅 error: \(error?.localizedDescription)")
                        })
                    }
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
