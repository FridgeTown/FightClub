//
//  SpecView.swift
//  FightClub
//
//  Created by Edward Lee on 12/27/24.
//

import SwiftUI

struct SpecView: View {
    var body: some View {
        HStack {
            VStack {
                Text("170kg")
                Text("몸무게")
            }
            Divider()
                           .frame(height: 40) // 구분선 높이 조정
                           .background(Color.gray.opacity(0.5)) // 구분선 색상
            VStack {
                Text("180CM")
                Text("키")
            }
        }
    }
}

#Preview {
    SpecView()
}
