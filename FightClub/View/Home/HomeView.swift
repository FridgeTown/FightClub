//
//  HomeView.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var profiles: [MatchUser] = []  // 추가
    
    init(viewModel: HomeViewModel = DIContainer.shared.makeHomeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 로고
            Image("title_logo")
                .resizable()
                .aspectRatio(16/9, contentMode: .fit)
                .frame(width: 100)
            
            SwipeView(profiles: $profiles,
                     onSwiped: { profile, hasLiked in
                let strId = profile.userId.toString()
                    if hasLiked {
                        Task {
                            print("Swipe userID", strId)
                            await viewModel.postRequest(id: strId)
                        }
                    } else {
                        print("여기는 거절")
                    }
            })
        }
        .background(Color(.background))
        .onAppear {
            Task {
                await viewModel.getUsers()
                if let usersData = viewModel.users.data {
                    profiles = usersData
                } else {
                    print("서버에서 데이터를 받아오지 못했습니다.")
                    profiles = [] // 기본값으로 빈 배열 설정
                }
            }
        }
    }
}
