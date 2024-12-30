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
            
            // 스와이프 뷰
            SwipeView(profiles: $profiles,  // 수정
                     onSwiped: { profile, hasLiked in
                print("\(profile.nickname)님과 \(hasLiked ? "매칭 성공!" : "매칭 실패")")
            })
        }
        .background(Color(.background))
        .onAppear {
            Task {
                await viewModel.getUsers()
                profiles = viewModel.users.data!  // viewModel의 데이터를 profiles에 할당
            }
        }
    }
}
