//
//  LiveListView.swift
//  FightClub
//
//  Created by Edward Lee on 1/8/25.
//

import SwiftUI

struct LiveListView: View {
    @StateObject private var viewModel: LiveListViewModel
    @State private var liveList: [LiveListModel] = []
    
    init(viewModel: LiveListViewModel = DIContainer.shared.makeLiveListModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let lives = viewModel.liveList.data, !lives.isEmpty {
                    List {
                        ForEach(lives) { live in
                            NavigationLink(destination: LiveWatchView(live: live)) {
                                LiveListRowView(live: live)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                } else {
                    LiveEmptyStateView()
                }
            }
            .navigationTitle("실시간 매치")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            Task {
                await viewModel.fetchLiveList()
            }
        }
    }
}

struct LiveListRowView: View {
    let live: LiveListModel
    
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
                
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.gray)
                    Text(live.place)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Text("LIVE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.mainRed)
                .clipShape(Capsule())
        }
        .padding(.vertical, 8)
    }
}

struct LiveEmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("현재 진행 중인 라이브가 없습니다")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("나중에 다시 확인해주세요")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
        }
    }
}

#Preview {
    LiveListView()
}
