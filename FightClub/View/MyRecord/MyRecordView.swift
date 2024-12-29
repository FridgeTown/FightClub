//
//  MyRecordView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI

struct MyRecordView: View {
    var body: some View {
        NavigationView {
            List() {
                Text("아아")
                Text("aa")
            }.navigationTitle("기록").navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MyRecordView()
}
