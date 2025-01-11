//
//  API.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import Alamofire

enum APIEndpoint {
    case logIn(email: String, provider: String, token: String)
    case signup(email: String, provider: String, token: String)
    case getUserInfo
    case getUserRecommend
    case postMatchRequest(opponentID: String)
    case postAcceptRequest(matchID: String)
    case postRejectRequest(matchID: String)
    case getPendingMatch
    case getNotificationSubscribe
    case postLiveStart(channelId: String, place: String)
    case getLiveList
    case postEndLiveMatch(matchId: String) //방송 종료
    
    // 엔드 포인트
    var url: String {
        switch self {
        case .logIn:
            return "http://3.34.46.87:8080/login" // 기존 로그인 URL
        case .signup:
            return "http://3.34.46.87:8080/signup" // 새로운 회원가입 URL
        case .getUserInfo:
            return "http://3.34.46.87:8080/user/info"
        case .getUserRecommend:
            return "http://3.34.46.87:8080/user/recommendation"
        case .postMatchRequest(let opponentID):
            return "http://3.34.46.87:8080/match/\(opponentID)"
        case .postRejectRequest(let matchID):
            return "http://3.34.46.87:8080/match/reject/\(matchID)"
        case .postAcceptRequest(let matchID):
            return "http://3.34.46.87:8080/match/accept/\(matchID)"
        case .getPendingMatch:
            return "http://3.34.46.87:8080/match/pending"
        case .getNotificationSubscribe:
            return "http://3.34.46.87:8080/notification/subscribe"
        case .signup:
            return "http://3.34.46.87:8080/signup" // 새로운 회원가입 URL
        case .postLiveStart:
            return "http://3.34.46.87:8080/live/start"
        case .getLiveList:
            return "http://3.34.46.87:8080/live/list"
        case .postEndLiveMatch(let matchID):
            return "http://3.34.46.87:8080/live/end/\(matchID)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .logIn, .signup, .postMatchRequest, .postAcceptRequest, .postRejectRequest, .postLiveStart, .postEndLiveMatch:
            return .post
        case .getUserInfo, .getUserRecommend, .getPendingMatch, .getNotificationSubscribe, .getLiveList:
            return .get
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
        case .getUserInfo:
            return nil
        case .getUserRecommend, .postMatchRequest, .postAcceptRequest, .postRejectRequest, .getPendingMatch, .getNotificationSubscribe:
            return nil
        case .postLiveStart(let channelId, let _):
            return ["place": "asdasd", "channelId": channelId, "title": "tests"]
        case .getLiveList, .postEndLiveMatch:
            return nil
        }
    }
    
    var header: HTTPHeaders? {
        switch self {
        case .logIn, .signup:
            return nil
        case .getUserInfo, .getUserRecommend, .postMatchRequest, .postRejectRequest, .getPendingMatch, .postAcceptRequest, .getNotificationSubscribe, .postLiveStart, .getLiveList, .postEndLiveMatch:
            if let token = try? TokenManager.shared.getAccessToken() {
                return ["Authorization": "Bearer \(token)"]
            }
            return nil
        }
    }
}
