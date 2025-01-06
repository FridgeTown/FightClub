//
//  API.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import Alamofire

enum APIEndpoint {
    case logIn(email: String, provider: String, token: String)
    case signup(email: String, provider: String, token: String) // signup 추가
    
    // 엔드 포인트
    var url: String {
        switch self {
        case .logIn:
            return "http://3.34.46.87:8080/login" // 기존 로그인 URL
        case .signup:
            return "http://3.34.46.87:8080/signup" // 새로운 회원가입 URL
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .logIn, .signup: // 둘 다 POST 메서드 사용
            return .post
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .logIn(let email, let provider, let idToken):
            print("Sending logIn parameters:", ["email": email, "provider": provider, "idToken": idToken])
            return ["email": email, "provider": provider, "idToken": idToken]
            
        case .signup(let email, let provider, let idToken): // signup의 매개변수 추가
            print("Sending register parameters:", ["email": email, "provider": provider, "idToken": idToken])
            return ["email": email, "provider": provider, "idToken": idToken]
        }
    }
}
