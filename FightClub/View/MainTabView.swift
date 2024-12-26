//
//  MainTabView.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI

struct MainTabView: View {
//    @State var appUser: AppUser
    
    var body: some View {
      TabView {
          HomeView()
          .tabItem {
              VStack {
                      Text("홈")
                  Image(systemName: "flame").renderingMode(.template)
                              }
          }
        Text("tab2")
          .tabItem {
              VStack {
                  Text("채팅")
                  Image(systemName: "message").renderingMode(.template)
                              }
          }
      }
      .font(.headline)
      .tint(.red)
      .accentColor(.red)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
