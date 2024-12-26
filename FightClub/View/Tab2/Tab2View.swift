//
//  Tab2View.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI

struct Tab2View: View {
    var body: some View {
        VStack {
            MatchRequestView()
            ChatListView()
        }
    }
}

#Preview {
    Tab2View()
}
