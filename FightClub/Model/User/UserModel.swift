//
//  UserModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/28/24.
//

import Foundation

struct UserModel: Decodable, Identifiable {
    let id: Int
    let email: String
    let provider: String
    let profileImg: String
    let gender: String
    let age: String
    let weight: String
    let height: String
    let bio: String
    let points: String
    let heartBeat: String
    let punchSpeed: String
    let kcal: String
    let weightClass: String
    let role: String
    let nickname: String
    let userMatches: String
    let challengedTo: String
    let challengedBy: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case provider
        case profileImg
        case gender
        case age
        case weight
        case height
        case bio
        case points
        case heartBeat
        case punchSpeed
        case kcal
        case weightClass
        case role
        case nickname
        case userMatches
        case challengedTo
        case challengedBy
    }
}
