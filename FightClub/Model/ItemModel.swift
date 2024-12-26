//
//  ItemModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import Foundation

struct ItemModel: Decodable, Identifiable {
    let id: Int
    let uid: String
    let brand: String
    let name: String
    let style: String
    let hop: String
    let yeast: String
    let malts: String
    let ibu: String
    let alcohol: String
    let blg: String

    enum CodingKeys: String, CodingKey {
        case id
        case uid
        case brand
        case name
        case style
        case hop
        case yeast
        case malts
        case ibu
        case alcohol
        case blg
    }
}
