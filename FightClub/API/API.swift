//
//  API.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import Alamofire

enum APIEndpoint {
    case logIn(email: String, provider: String, token: String)
    case getUserInfo
    case getUserRecommend
    
    // 엔드 포인트
    var url: String {
        switch self {
        case .logIn:
            return "http://3.34.46.87:8080/login"
        case .getUserInfo:
            return "http://3.34.46.87:8080/user/info"
        case .getUserRecommend:
            return "http://3.34.46.87:8080/user/recommendation"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .logIn:
            return .post
        case .getUserInfo:
            return .get
        case .getUserRecommend:
            return .get
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .logIn(let email, let provider, let idToken):
            print(["email": email, "provider": provider, "idToken": idToken])
            return ["email": email, "provider": provider, "idToken": idToken]
        case .getUserInfo:
            return nil
        case .getUserRecommend:
            return nil
        }
    }
    
    var header: HTTPHeaders? {
        switch self {
        case .logIn:
            return nil
        case .getUserInfo, .getUserRecommend:
            if let token = try? TokenManager.shared.getAccessToken() {
                return ["Authorization": "Bearer \(token)"]
            }
            return nil
        }
    }
}

