//
//  ItemView.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import SwiftUI

struct UserView: View {
    let item: ItemModel
    
    var body: some View {
            VStack(spacing: 8) {
                Text("\(item.name)")
                    .font(.title2)
                    .fontWeight(.medium)
            }
        }
}

