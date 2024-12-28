//
//  ContentView.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import SwiftUI

//        MainTabView()
//        GoogleLoginDemo()
//        SignupFirstView()

struct ContentView: View {
    
    @State var isLaunching: Bool = true
    
    var body: some View {
        if isLaunching {
            SplashView()
                .opacity(isLaunching ? 1 : 0)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        withAnimation(.easeIn(duration: 1)) {
                                isLaunching = false
                        }
                    }
                }
        } else {
            MainTabView()
        }
    }
}

struct SplashView: View {
    
    var body: some View {
        ZStack {
            Color.background
            Image("title_logo")
                .resizable()
                .aspectRatio(16/9, contentMode: .fit)
                .frame(width: 200)
            
        }
    }
}
