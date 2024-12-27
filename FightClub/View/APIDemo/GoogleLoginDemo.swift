//
//  GoogleLoginDemo.swift
//  FightClub
//
//  Created by Edward Lee on 12/28/24.
//

import SwiftUI
import GoogleSignInSwift

struct GoogleLoginDemo: View {
    @StateObject private var viewModel = GoogleOAuthViewModel()
    
    var body: some View {
        VStack {
            GoogleSignInButton {
                viewModel.signIn()
            }
        }
        Text(viewModel.givenEmail ?? "")
        Text(viewModel.oauthUserData.idToken ?? "")
    }
}

#Preview {
    GoogleLoginDemo()
}
