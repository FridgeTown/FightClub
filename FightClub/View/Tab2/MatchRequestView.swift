//
//  MatchRequestView.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI

struct MatchRequestView: View {
    @StateObject private var viewModel: MatchRequestModel
    
    init(viewModel: MatchRequestModel = DIContainer.shared.makeMatchRequestModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 16) {
            headerView
            
            if viewModel.isLoading {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else {
                requestListView
            }
        }
        .onAppear {
            Task {
                await viewModel.getPendingList()
            }
        }
        .padding()
    }
    
    // MARK: - Subviews
    private var headerView: some View {
        Text("스파링 요청")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(Color.mainRed)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }
    
    private var requestListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.matchs.data ?? []) { request in
                    MatchRequestCard(
                        request: request,
                        onAccept: { handleAccept(request) },
                        onDecline: { handleDecline(request) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func errorView(message: String) -> some View {
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

// MARK: - MatchRequestCard
struct MatchRequestCard: View {
    let request: MatchRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        VStack {
            HStack(spacing: 20) {
                profileImage
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.nickName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
//                    SpecView(height: request.height, weight: request.weight)
                }
                
                Spacer()
                
                actionButtons
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.mainRed.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.mainRed.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var profileImage: some View {
        AsyncImage(url: URL(string: request.profileImg)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Image("profile_placeholder")
                .resizable()
        }
        .frame(width: 60, height: 60)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.mainRed, Color.mainRed.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(radius: 3)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            ActionButton(
                action: onDecline,
                icon: "xmark",
                color: Color.mainRed,
                size: 44
            )
            
            ActionButton(
                action: onAccept,
                icon: "checkmark",
                color: Color.mainRed,
                size: 44
            )
        }
    }
}

// MARK: - ActionButton
struct ActionButton: View {
    let action: () -> Void
    let icon: String
    let color: Color
    let size: CGFloat
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.opacity(0.15))
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(color)
                )
                .frame(width: size, height: size)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - ScaleButtonStyle
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Preview
//struct MatchRequestView_Previews: PreviewProvider {
//    static var previews: some View {
//        MatchRequestView(matchRequests: [
//            MatchRequest(id: 1, nickname: "Boxer1"),
//            MatchRequest(id: 2, nickname: "Boxer2"),
//            MatchRequest(id: 3, nickname: "Boxer3")
//        ])
//        .background(Color(.systemGroupedBackground))
//    }
//}
