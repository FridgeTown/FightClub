//
//  LiveListView.swift
//  FightClub
//
//  Created by Edward Lee on 1/2/25.
//

import SwiftUI
import Foundation

struct LiveListView: View {
    var body: some View {
        NavigationView {
            VStack {
                Button("로그아웃") {
                    try? TokenManager.shared.clearAllTokens()
                }
            }
            .navigationTitle("실시간 매치")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    LiveListView()
}
