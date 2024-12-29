//
//  API.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import Alamofire

enum APIEndpoint {
    case logIn(email: String, provider: String, token: String)
    
    // 엔드 포인트
    var url: String {
        switch self {
        case .logIn:
            return "http://3.34.46.87:8080/login"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .logIn:
            return .post
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .logIn(let email, let provider, let idToken):
            print(["email": email, "provider": provider, "idToken": idToken])
            return ["email": email, "provider": provider, "idToken": idToken]
        }
    }
}

