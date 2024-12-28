//
//  HomeView.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI

struct HomeView: View {
    @State var profiles: [ProfileCardModel] = [
        ProfileCardModel(
            userId: "user1",
            name: "강철주먹",
            age: 28,
            pictures: [UIImage(named: "deny")!],
            weightClass: "미들급",
            record: (wins: 12, losses: 3),
            style: "아웃복서",
            bio: "3년차 아마추어 복서입니다. 기술 교류하면서 함께 성장하고 싶습니다."
        ),
        ProfileCardModel(
            userId: "user2",
            name: "박파이터",
            age: 25,
            pictures: [UIImage(named: "deny")!],
            weightClass: "라이트급",
            record: (wins: 8, losses: 2),
            style: "인파이터",
            bio: "주 4회 운동하는 열정적인 복서입니다. 스파링 환영합니다."
        ),
        ProfileCardModel(
            userId: "user3",
            name: "김챔피온",
            age: 30,
            pictures: [UIImage(named: "elon_musk")!],
            weightClass: "헤비급",
            record: (wins: 15, losses: 4),
            style: "스위처",
            bio: "전국 아마추어 대회 입상 경력. 실력있는 스파링 파트너 찾습니다."
        )
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // 로고
            Image("title_logo")
                .resizable()
                .aspectRatio(16/9, contentMode: .fit)
                .frame(width: 100)
            
            // 스와이프 뷰
            SwipeView(profiles: $profiles,
                     onSwiped: { profile, hasLiked in
                print("\(profile.name)님과 \(hasLiked ? "매칭 성공!" : "매칭 실패")")
            })
        }
        .background(Color(.background))
    }
}

//#Preview {
//    HomeView()
//}
