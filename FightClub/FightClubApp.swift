//
//  FightClubApp.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import SwiftUI
import GoogleSignIn

@main
struct FightClubApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
