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

struct ProfileCardModel {
    let userId: String
    let name: String
    let age: Int
    let pictures: [UIImage]
    let weightClass: String
    let record: (wins: Int, losses: Int)
    let style: String
    let bio: String
}

struct SwipeView: View {
    @Binding var profiles: [ProfileCardModel]
    @State var swipeAction: SwipeAction = .doNothing
    var onSwiped: (ProfileCardModel, Bool) -> ()
    
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
                    
                    ForEach(profiles.indices, id: \.self) { index in
                        let model: ProfileCardModel = profiles[index]
                        
                        if(index == profiles.count - 1) {
                            SwipeableCardView(model: model, swipeAction: $swipeAction, onSwiped: performSwipe)
                        } else if(index == profiles.count - 2) {
                            SwipeCardView(model: model)
                        }
                    }
                }
            }.padding()
            Spacer()
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
    
    private func performSwipe(userProfile: ProfileCardModel, hasLiked: Bool) {
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
    
    let model: ProfileCardModel
    @State private var dragOffset = CGSize.zero
    @Binding var swipeAction: SwipeAction
    
    var onSwiped: (ProfileCardModel, Bool) -> ()
    
    var body: some View {
        SwipeCardView(model: model)
            .overlay(
                HStack{
                    Text(like).font(.largeTitle).bold().foregroundGradient(colors: [Color(hex: "6ceac5"), Color(hex: "16dba1")]).padding().overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LinearGradient(gradient: .init(colors: [Color(hex: "6ceac5"), Color(hex: "16dba1")]),
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing), lineWidth: 4)
                    ).rotationEffect(.degrees(-30)).opacity(getLikeOpacity())
                    Spacer()
                    Text(nope).font(.largeTitle).bold().foregroundGradient(colors: [Color(hex: "ff6560"), Color(hex: "f83770")]).padding().overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LinearGradient(gradient: .init(colors: [Color(hex: "ff6560"), Color(hex: "f83770")]),
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing), lineWidth: 4)
                    ).rotationEffect(.degrees(30)).opacity(getDislikeOpacity())

                }.padding(.top, 45).padding(.leading, 20).padding(.trailing, 20)
                ,alignment: .top)
            .offset(x: self.dragOffset.width,y: self.dragOffset.height)
            .rotationEffect(.degrees(self.dragOffset.width * -0.06), anchor: .center)
            .simultaneousGesture(DragGesture(minimumDistance: 0.0).onChanged{ value in
                self.dragOffset = value.translation
            }.onEnded{ value in
                performDragEnd(value.translation)
                print("onEnd: \(value.location)")
            }).onChange(of: swipeAction, perform: { newValue in
                if newValue != .doNothing {
                    performSwipe(newValue)
                }
                
            })
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
    let model: ProfileCardModel
    @State private var currentImageIndex: Int = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geometry in
                Image(uiImage: model.pictures[currentImageIndex])
                    .centerCropped()
                    .gesture(DragGesture(minimumDistance: 0).onEnded({ value in
                        if value.translation.equalTo(.zero) {
                            if(value.location.x <= geometry.size.width/2) {
                                showPrevPicture()
                            } else {
                                showNextPicture()
                            }
                        }
                    }))
            }
            
            // 프로필 정보 오버레이
            VStack {
                // 이미지 인디케이터
                if(model.pictures.count > 1) {
                    HStack {
                        ForEach(0..<model.pictures.count, id: \.self) { index in
                            Rectangle()
                                .frame(height: 3)
                                .foregroundColor(index == currentImageIndex ? .white : .gray)
                                .opacity(index == currentImageIndex ? 1 : 0.5)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // 프로필 정보
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(model.name)
                            .font(.title)
                            .fontWeight(.bold)
                        Text("\(model.age)")
                            .font(.title2)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    
                    // 복싱 스탯
                    HStack(spacing: 15) {
                        StatLabel(title: "체중", value: model.weightClass)
                        StatLabel(title: "키", value: "178")
//                        StatLabel(title: "", value: model.style)
                    }
                    .padding(.top, 4)
                    
                    // 자기소개
                    if !model.bio.isEmpty {
                        Text(model.bio)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                            .padding(.top, 4)
                    }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(0.7, contentMode: .fit)
        .background(.white)
        .cornerRadius(15)
        .shadow(color: Color.mainRed.opacity(0.2), radius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.mainRed.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func showNextPicture() {
        if currentImageIndex < model.pictures.count - 1 {
            currentImageIndex += 1
        }
    }
    
    private func showPrevPicture() {
        if currentImageIndex > 0 {
            currentImageIndex -= 1
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

struct SwipeView_Previews: PreviewProvider {
    @State static private var profiles: [ProfileCardModel] = [
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!], weightClass: "2A", record: (wins: 10, losses: 15), style: "킥", bio: "마짱뜨실분"),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!], weightClass: "2A", record: (wins: 10, losses: 15), style: "킥", bio: "마짱뜨실분")
    ]
    
    static var previews: some View {
        SwipeView(profiles: $profiles, onSwiped: {_,_ in})
    }
}
