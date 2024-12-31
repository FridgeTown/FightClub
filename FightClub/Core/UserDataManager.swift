//
//  UserDataManager.swift
//  FightClub
//
//  Created by Edward Lee on 12/31/24.
//

import Foundation

class UserDataManager {
    static let shared = UserDataManager()
       private init() {}
       
       // 현재 사용자 데이터
       private var userData: UserData?
       
       // UserData 저장
       func setUserData(_ data: UserData) {
           userData = data
       }
       
       // UserData 가져오기
       func getUserData() -> UserData? {
           return userData
       }
       
       // 특정 데이터 가져오기 위한 편의 메서드들
       var userId: Int? {
           return userData?.id
       }
       
       var nickname: String? {
           return userData?.nickname
       }
       
       var email: String? {
           return userData?.email
       }
       
       var chatToken: String? {
           return userData?.chatToken
       }
       
       // UserData 초기화 (로그아웃 시 사용)
       func clearUserData() {
           userData = nil
       }
}
