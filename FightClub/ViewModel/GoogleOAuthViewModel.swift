//
//  GoogleOAuthViewModel.swift
//  FightClub
//
//  Created by Edward Lee on 12/28/24.
//

import GoogleSignIn
import SwiftUI

class GoogleOAuthViewModel: ObservableObject {
    @Published var oauthUserData = OAuthUserData()
    @Published var errorMessage: String?
    @Published var givenEmail: String?
    
    func checkUserInfo() {
        if GIDSignIn.sharedInstance.currentUser != nil {
            let user = GIDSignIn.sharedInstance.currentUser
            guard let user = user else {
                return
            }
            if let email = user.profile?.email {
                self.givenEmail = email
            }
            oauthUserData.oauthId = user.userID ?? ""
            oauthUserData.idToken = user.idToken?.tokenString ?? ""
        } else {
            self.errorMessage = "error: Not Logged In"
        }
    }
    
    func signIn() {
            guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
                return
            }
            
            GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingViewController)
            { _, error in
                if let error = error {
                    self.errorMessage = "error: \(error.localizedDescription)"
                }
                
                self.checkUserInfo()
            }
        }
        
        func signOut() {
            GIDSignIn.sharedInstance.signOut()
        }
    }
