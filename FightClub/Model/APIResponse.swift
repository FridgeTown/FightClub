//
//  APIResponse.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let status: Int
    let message: String?
    let data: T?
}

