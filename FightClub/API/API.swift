//
//  API.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import Alamofire

enum APIEndpoint {
    case getItems
    
    // 엔드 포인트
    var url: String {
        switch self {
        case .getItems:
            return "https://random-data-api.com/api/v2/beers?size=10"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getItems:
            return .get
        }
    }
    
    // 나중 post 시 파라미터 쓸것 정의
    var parameters: Parameters? {
        switch self {
        case .getItems:
            return nil
        }
    }
}

