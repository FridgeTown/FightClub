//
//  MatchUser.swift
//  FightClub
//
//  Created by Edward Lee on 12/30/24.
//

import Foundation

struct MatchUser: Decodable {
    let userId: Int
    let nickname: String
    let height: Int
    let weight: Int
    let bio: String
    let gender: String
    let profileImg: String
    let weightClass: String
}

