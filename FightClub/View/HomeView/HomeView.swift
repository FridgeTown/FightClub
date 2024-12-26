//
//  HomeView.swift
//  FightClub
//
//  Created by Edward Lee on 12/26/24.
//

import SwiftUI

struct HomeView: View {
    @State var profiles: [ProfileCardModel] = [
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!]),
        ProfileCardModel(userId: "defdwsfewfes", name: "Michael Jackson", age: 50, pictures: [UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!,UIImage(named: "elon_musk")!,UIImage(named: "jeff_bezos")!])
    ]
    
    var body: some View {
        VStack {
            Image("title_logo")
                .resizable()
                .aspectRatio(16/9, contentMode: .fit) // 16:9 비율 적용
                .frame(width: 100) // 가로 기준 크기 지정
            SwipeView(profiles: $profiles,
                      onSwiped: { userModel, hasLiked in print("test")}
            )
        }
    }
}

//#Preview {
//    HomeView()
//}
