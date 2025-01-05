//
//  Tab2View.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI
import TalkPlus

// MARK: - TalkPlus Channel Delegate Handler
class TalkPlusChannelHandler: NSObject, TPChannelDelegate {
    // MARK: - Properties
    var onChannelCreated: (() -> Void)?
    var onChannelUpdated: (() -> Void)?
    var onMessageReceived: ((TPChannel, TPMessage) -> Void)?
    
    // MARK: - Channel Events
    func channelAdded(_ tpChannel: TPChannel!) {
        DispatchQueue.main.async { [weak self] in
            self?.onChannelCreated?()
        }
    }
    
    func channelChanged(_ tpChannel: TPChannel!) {
        DispatchQueue.main.async { [weak self] in
            self?.onChannelUpdated?()
        }
    }
    
    func messageReceived(_ tpChannel: TPChannel!, message tpMessage: TPMessage!) {
        DispatchQueue.main.async { [weak self] in
            if let channel = tpChannel, let message = tpMessage {
                self?.onMessageReceived?(channel, message)
            }
        }
    }
    
    // MARK: - Required Protocol Methods
    func memberAdded(_ tpChannel: TPChannel!, users: [TPMember]!) {}
    func memberLeft(_ tpChannel: TPChannel!, users: [TPMember]!) {}
    func messageDeleted(_ tpChannel: TPChannel!, message tpMessage: TPMessage!) {}
    func channelRemoved(_ tpChannel: TPChannel!) {}
    func publicMemberAdded(_ tpChannel: TPChannel!, users: [TPMember]!) {}
    func publicMemberLeft(_ tpChannel: TPChannel!, users: [TPMember]!) {}
    func publicChannelAdded(_ tpChannel: TPChannel!) {}
    func publicChannelChanged(_ tpChannel: TPChannel!) {}
    func publicChannelRemoved(_ tpChannel: TPChannel!) {}
}

struct Tab2View: View {
    // MARK: - Properties
    @StateObject private var matchViewModel: MatchRequestModel = DIContainer.shared.makeMatchRequestModel()
    @StateObject private var chatViewModel: ChatListModel = DIContainer.shared.makeChatListViewModel()
    @State private var showFullList = false
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // 스파링 요청 섹션 (있을 경우에만)
            if let requests = matchViewModel.matchs.data, !requests.isEmpty {
                matchRequestSection
                    .padding(.top)
                
                Divider()
                    .padding(.horizontal)
            }
            
            // 채팅 섹션
            ChatListView()
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showFullList) {
            NavigationView {
                MatchRequestView(viewModel: matchViewModel)
                    .navigationBarItems(
                        trailing: Button("닫기") { showFullList = false }
                    )
            }
        }
        .task {
            await matchViewModel.getPendingList()
            await chatViewModel.getChatList()
        }
    }
    
    // MARK: - Subviews
    private var matchRequestSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("스파링 요청")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.mainRed)
                
                Spacer()
                
                if let requests = matchViewModel.matchs.data, requests.count > 3 {
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
            .padding(.horizontal)
             
            LimitedMatchRequestView(
                limit: 3,
                viewModel: matchViewModel,
                onMatchStatusChanged: {
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        await chatViewModel.getChatList()
                    }
                }
            )
        }
    }
}

// MARK: - LimitedMatchRequestView
struct LimitedMatchRequestView: View {
    // MARK: - Properties
    @StateObject private var viewModel: MatchRequestModel
    let limit: Int
    let onMatchStatusChanged: () -> Void
    
    // MARK: - Initialization
    init(limit: Int, viewModel: MatchRequestModel, onMatchStatusChanged: @escaping () -> Void) {
        self.limit = limit
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onMatchStatusChanged = onMatchStatusChanged
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
                onAccept: {
                    Task {
                        await handleAccept(request)
                    }
                },
                onDecline: { handleDecline(request) }
            )
        }
    }
    
    private func errorView(_ message: String) -> some View {
        Text(message)
            .foregroundColor(.red)
    }
    
    // MARK: - Actions
    private func handleAccept(_ request: MatchRequest) async {
        do {
            await viewModel.acceptMatch(matchId: request.id)
            await viewModel.getPendingList()
            onMatchStatusChanged()
        } catch {
            print("매칭 수락 실패: \(error)")
        }
    }
    
    private func handleDecline(_ request: MatchRequest) {
        // TODO: 거절 로직 구현
        onMatchStatusChanged()
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
