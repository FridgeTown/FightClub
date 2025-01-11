//
//  LiveListModel.swift
//  FightClub
//
//  Created by Edward Lee on 1/8/25.
//

import Foundation

struct LiveListModel: Codable, Identifiable {
    let id: Int
    let title: String
    let place: String
    let thumbNail: String
    
    enum CodingKeys: String, CodingKey {
        case id = "matchId"
        case title
        case place
        case thumbNail
    }
}
