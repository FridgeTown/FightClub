//
//  LiveListModel.swift
//  FightClub
//
//  Created by Edward Lee on 1/8/25.
//

import Foundation

struct LiveListModel: Decodable, Identifiable {
    let id = UUID()
    let matchId: Int
    let title: String
    let thumbNail: String
    let place: String
}


