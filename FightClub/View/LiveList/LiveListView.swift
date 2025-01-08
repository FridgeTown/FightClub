//
//  LiveListView.swift
//  FightClub
//
//  Created by Edward Lee on 1/8/25.
//

import SwiftUI

struct LiveListView: View {
    @State private var liveList: [LiveListModel] = [
        LiveListModel(matchId: 0, title: "김현영 VS 이동인", thumbNail: "", place: "경기체고 복싱장"),
        LiveListModel(matchId: 0, title: "김남훈 VS 윤석열", thumbNail: "", place: "테이큰 광교"),
        LiveListModel(matchId: 0, title: "야스나리 케이스케 VS 김현우", thumbNail: "", place: "킵고잉 복싱장 영통")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(liveList) { live in
                    NavigationLink(destination: LiveWatchView(live: live)) {
                        LiveListRowView(live: live)
                    }
                }
            }
            .navigationTitle("실시간 매치")
            .navigationBarTitleDisplayMode(.large)
            .listStyle(.plain)
        }
    }
}

struct LiveListRowView: View {
    var live: LiveListModel
    var body: some View {
        HStack(spacing: 12) {
            // 썸네일 이미지
            Image("title_logo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 8) {
                Text(live.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // 위치 정보
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.gray)
                    Text(live.place)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // 라이브 표시
            Text("LIVE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red)
                .clipShape(Capsule())
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    LiveListView()
}
