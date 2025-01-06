//
//  MatchRequest.swift
//  FightClub
//
//  Created by Edward Lee on 12/31/24.
//

import Foundation

struct MatchRequest: Decodable, Identifiable {
    let id: Int // matchId를 id로 사용
    let challengedBy: Int
    let status: String
    let nickName: String
    let height: Int
    let weight: Int
    let profileImg: String
    
    private enum CodingKeys: String, CodingKey {
        case id = "matchId" // matchId를 id로 매핑
        case challengedBy = "challengedBy"
        case status = "status"
        case nickName = "nickName"
        case height = "height"
        case weight = "weight"
        case profileImg = "profileImg"
    }
}
