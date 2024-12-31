//
//  Tab2View.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI

struct Tab2View: View {
    // MARK: - Properties
    @StateObject private var viewModel: MatchRequestModel = DIContainer.shared.makeMatchRequestModel()
    @State private var showFullList = false
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                matchRequestSection
                
                Divider()
                    .padding(.horizontal)
                
                ChatListView()
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showFullList) {
            fullListSheet
        }
        .onAppear {
            Task {
                await viewModel.getPendingList()
            }
        }
    }
    
    // MARK: - Subviews
    private var matchRequestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            LimitedMatchRequestView(limit: 3, viewModel: viewModel)
        }
    }
    
    private var headerRow: some View {
        HStack {
            Text("스파링 요청")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.mainRed)
            
            Spacer()
            
            moreButton
        }
        .padding(.horizontal)
    }
    
    private var moreButton: some View {
        Group {
            if let requests = viewModel.matchs.data, requests.count > 3 {
                Button(action: { showFullList = true }) {
                    HStack(spacing: 4) {
                        Text("더보기")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color.mainRed)
                }
            }
        }
    }
    
    private var fullListSheet: some View {
        NavigationView {
            MatchRequestView(viewModel: viewModel)
                .navigationBarItems(
                    trailing: Button("닫기") { showFullList = false }
                )
        }
    }
}

// MARK: - LimitedMatchRequestView
struct LimitedMatchRequestView: View {
    // MARK: - Properties
    @StateObject private var viewModel: MatchRequestModel
    let limit: Int
    
    // MARK: - Initialization
    init(limit: Int, viewModel: MatchRequestModel) {
        self.limit = limit
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 16) {
            content
        }
        .padding(.horizontal)
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
        } else if let errorMessage = viewModel.errorMessage {
            errorView(errorMessage)
        } else {
            requestList
        }
    }
    
    private var requestList: some View {
        let limitedRequests = Array((viewModel.matchs.data ?? []).prefix(limit))
        return ForEach(limitedRequests) { request in
            MatchRequestCard(
                request: request,
                onAccept: { handleAccept(request) },
                onDecline: { handleDecline(request) }
            )
        }
    }
    
    private func errorView(_ message: String) -> some View {
        Text(message)
            .foregroundColor(.red)
    }
    
    // MARK: - Actions
    private func handleAccept(_ request: MatchRequest) {
        // TODO: 수락 로직 구현
    }
    
    private func handleDecline(_ request: MatchRequest) {
        // TODO: 거절 로직 구현
    }
}

// MARK: - Preview
#if DEBUG
struct Tab2View_Previews: PreviewProvider {
    static var previews: some View {
        Tab2View()
    }
}
#endif
