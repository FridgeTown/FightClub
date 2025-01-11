//
//  SwipeView.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI

enum SwipeAction{
    case swipeLeft, swipeRight, doNothing
}

struct SwipeView: View {
    @Binding var profiles: [MatchUser]
    @State var swipeAction: SwipeAction = .doNothing
    var onSwiped: (MatchUser, Bool) -> ()
    
    var body: some View {
        VStack {
            Spacer()
            VStack {
                ZStack {
                    Text("더 이상 매칭 가능한 스파링 파트너가 없습니다")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(Color(UIColor.systemGray))
                        .multilineTextAlignment(.center)
                        .opacity(profiles.isEmpty ? 1 : 0)
                    
                    ForEach(profiles.indices, id: \.self) { index in
                        let model: MatchUser = profiles[index]
                        
                        if(index == profiles.count - 1) {
                            SwipeableCardView(model: model, swipeAction: $swipeAction, onSwiped: performSwipe)
                        } else if(index == profiles.count - 2) {
                            SwipeCardView(model: model)
                        }
                    }
                }
            }.padding()
            Spacer()
            
            if !profiles.isEmpty {
                HStack {
                    Spacer()
                    GradientOutlineButton(
                        action: { swipeAction = .swipeLeft},
                        iconName: "xmark.circle.fill",
                        colors: [Color.mainRed.opacity(0.8), Color.mainRed]
                    )
                    Spacer()
                    GradientOutlineButton(
                        action: { swipeAction = .swipeRight },
                        iconName: "figure.boxing",
                        colors: [Color.mainRed.opacity(0.8), Color.mainRed]
                    )
                    Spacer()
                }.padding(.bottom)
            }
        }
    }
    
    private func performSwipe(userProfile: MatchUser, hasLiked: Bool) {
        removeTopItem()
        onSwiped(userProfile, hasLiked)
    }
    
    private func removeTopItem() {
        profiles.removeLast()
    }
}

//Swipe functionality
struct SwipeableCardView: View {

    private let nope = "NOPE"
    private let like = "LIKE"
    private let screenWidthLimit = UIScreen.main.bounds.width * 0.5
    
    let model: MatchUser
    @State private var dragOffset = CGSize.zero
    @Binding var swipeAction: SwipeAction
    
    var onSwiped: (MatchUser, Bool) -> ()
    
    var body: some View {
        SwipeCardView(model: model)
            .overlay(
                HStack {
                    Text(like)
                        .font(.largeTitle)
                        .bold()
                        .foregroundGradient(colors: [Color(hex: "6ceac5"), Color(hex: "16dba1")])
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(LinearGradient(gradient: .init(colors: [Color(hex: "6ceac5"), Color(hex: "16dba1")]),
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing), lineWidth: 4)
                        )
                        .rotationEffect(.degrees(-30))
                        .opacity(getLikeOpacity())
                    Spacer()
                    Text(nope)
                        .font(.largeTitle)
                        .bold()
                        .foregroundGradient(colors: [Color(hex: "ff6560"), Color(hex: "f83770")])
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(LinearGradient(gradient: .init(colors: [Color(hex: "ff6560"), Color(hex: "f83770")]),
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing), lineWidth: 4)
                        )
                        .rotationEffect(.degrees(30))
                        .opacity(getDislikeOpacity())
                }
                .padding(.top, 45)
                .padding(.horizontal, 20),
                alignment: .top
            )
            .offset(x: self.dragOffset.width,y: self.dragOffset.height)
            .rotationEffect(.degrees(self.dragOffset.width * -0.06), anchor: .center)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0.0)
                    .onChanged { value in
                        self.dragOffset = value.translation
                    }
                    .onEnded { value in
                        performDragEnd(value.translation)
                        print("onEnd: \(value.location)")
                    }
            )
            .onChange(of: swipeAction) { oldValue, newValue in
                if newValue != .doNothing {
                    performSwipe(newValue)
                }
            }
    }
    
    private func performSwipe(_ swipeAction: SwipeAction){
        withAnimation(.linear(duration: 0.3)){
            if(swipeAction == .swipeRight){
                self.dragOffset.width += screenWidthLimit * 2
            } else if(swipeAction == .swipeLeft){
                self.dragOffset.width -= screenWidthLimit * 2
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onSwiped(model, swipeAction == .swipeRight)
        }
        self.swipeAction = .doNothing
    }
    
    private func performDragEnd(_ translation: CGSize){
        let translationX = translation.width
        if(hasLiked(translationX)){
            withAnimation(.linear(duration: 0.3)){
                self.dragOffset = translation
                self.dragOffset.width += screenWidthLimit
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onSwiped(model, true)
            }
        } else if(hasDisliked(translationX)){
            withAnimation(.linear(duration: 0.3)){
                self.dragOffset = translation
                self.dragOffset.width -= screenWidthLimit
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onSwiped(model, false)
            }
        } else{
            withAnimation(.default){
                self.dragOffset = .zero
            }
        }
    }
    
    private func hasLiked(_ value: Double) -> Bool{
        let ratio: Double = dragOffset.width / screenWidthLimit
        return ratio >= 1
    }
    
    private func hasDisliked(_ value: Double) -> Bool{
        let ratio: Double = -dragOffset.width / screenWidthLimit
        return ratio >= 1
    }
    
    private func getLikeOpacity() -> Double{
        let ratio: Double = dragOffset.width / screenWidthLimit;
        if(ratio >= 1){
            return 1.0
        } else if(ratio <= 0){
            return 0.0
        } else {
            return ratio
        }
    }
    
    private func getDislikeOpacity() -> Double{
        let ratio: Double = -dragOffset.width / screenWidthLimit;
        if(ratio >= 1){
            return 1.0
        } else if(ratio <= 0){
            return 0.0
        } else {
            return ratio
        }
    }
}

//Card design
struct SwipeCardView: View {
    let model: MatchUser
    
    var body: some View {
        ZStack(alignment: .bottom) {
            CardBackgroundView(model: model)
            CardContentView(model: model)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(0.7, contentMode: .fit)
        .background(Color("card_background"))
        .cornerRadius(15)
        .shadow(color: Color.mainRed.opacity(0.2), radius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.mainRed.opacity(0.1), lineWidth: 1)
        )
    }
}

struct CardBackgroundView: View {
    let model: MatchUser
    
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: URL(string: model.profileImg)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                case .failure(_):
                    Image(systemName: "person.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width * 0.5)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color.gray.opacity(0.3))
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

struct CardContentView: View {
    let model: MatchUser
    
    var body: some View {
        VStack {
//            WeightClassBadge(weightClass: model.weightClass)
            Spacer()
            ProfileInfoView(model: model)
        }
    }
}

struct WeightClassBadge: View {
    let weightClass: String
    
    var body: some View {
        HStack {
            Spacer()
            Text(weightClass)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.mainRed)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                )
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .padding(.top, 16)
        .padding(.trailing, 16)
    }
}

struct ProfileInfoView: View {
    let model: MatchUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.nickname)
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
            
            BoxingStatsView(model: model)
            
            if !model.bio.isEmpty {
                Text(model.bio)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
                    .padding(.top, 4)
            }
            
//            PreferredScheduleView(days: model.preferredDays, times: model.preferredTimes)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .foregroundColor(.white)
    }
}

struct BoxingStatsView: View {
    let model: MatchUser
    
    var body: some View {
        HStack(spacing: 15) {
            StatLabel(title: "체중", value: "\(model.weight)kg")
            StatLabel(title: "키", value: "\(model.height)cm")
//            StatLabel(title: "경력", value: model.experience)
        }
        .padding(.top, 4)
    }
}

struct PreferredScheduleView: View {
    let days: [String]
    let times: [String]
    
    var body: some View {
        VStack(spacing: 8) {
            if !days.isEmpty {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.mainRed)
                    Text(days.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            if !times.isEmpty {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.mainRed)
                    Text(times.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}

struct StatLabel: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}


