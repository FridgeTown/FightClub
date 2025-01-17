//
//  PunchGameModel.swift
//  FightClub
//
//  Created by Edward Lee on 1/16/25.
//

import Foundation

struct PunchGameModel: Decodable {
    let opponentId: Int
    let opponentNickname: String
    let opponentGender: String
    let opponentAge: Int
    let opponentHeight: Int
    let opponentWeight: Int
    let opponentWeightClass: String
    let opponentProfileImg: String
}
