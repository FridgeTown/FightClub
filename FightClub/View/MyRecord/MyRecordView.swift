//
//  MyRecordView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI

struct MyRecordView: View {
    private let mainRed = Color("mainRed")
    private let backgroundColor = Color("background")
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                RecordListView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

#Preview {
    MyRecordView()
}
