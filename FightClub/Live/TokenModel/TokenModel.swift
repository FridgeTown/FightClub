//
//  TokenModel.swift
//  FightClub
//
//  Created by Edward Lee on 1/6/25.
//

import Foundation

struct TokenRequest: Codable {
    let roomName: String
    let participantName: String
}

struct TokenResponse: Codable {
    let token: String
}

struct TokenResponseRTC: Codable {
    let token: String?
}


