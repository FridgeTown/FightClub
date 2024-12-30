//
//  UserData.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import Foundation

struct UserData: Decodable {
    let id: Int
    let email: String
    let provider: String
    let profileImg: String?
    let gender: String?
    let age: Int?
    let weight: Double?
    let height: Double?
    let bio: String?
    let points: Int?
    let heartBeat: Int?
    let punchSpeed: Int?
    let kcal: Int?
    let weightClass: String?
    let role: String?
    let nickname: String?
    let accessToken: String?
    let chatToken: String?
}
