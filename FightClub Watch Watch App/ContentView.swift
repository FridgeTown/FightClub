//
//  ContentView.swift
//  FightClub Watch App
//
//  Created by Edward Lee on 1/13/25.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var workoutManager = WorkoutManager.shared
    
    var body: some View {
        ZStack {
            // 배경
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                StartView()
//                if workoutManager.isWorkoutInProgress {
//                    // 운동 중인 경우
//                    WorkoutView()
//                } else {
//                    // 대기 상태
//                    StartView()
//                }
            }
        }
    }
}

// 운동 시작 전 화면
struct StartView: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "figure.boxing")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("복싱 세션")
                .font(.system(size: 20, weight: .bold))
            
            Text("iPhone에서 녹화를\n시작하면 자동으로\n데이터 수집이 시작됩니다")
                .multilineTextAlignment(.center)
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .padding()
    }
}

// 운동 중인 화면
struct WorkoutView: View {
    @StateObject private var workoutManager = WorkoutManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("운동중 화면")
                // 심박수
//                MetricView(
//                    title: "심박수",
//                    value: Int(workoutManager.heartRate),
//                    unit: "BPM",
//                    systemImage: "heart.fill"
//                )
//                
//                // 칼로리
//                MetricView(
//                    title: "소모 칼로리",
//                    value: Int(workoutManager.activeCalories),
//                    unit: "kcal",
//                    systemImage: "flame.fill"
//                )
            }
            .padding()
        }
    }
}

// 측정값 표시 컴포넌트
struct MetricView: View {
    let title: String
    let value: Int
    let unit: String
    let systemImage: String
    
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.red)
                Text(title)
                    .foregroundColor(.gray)
            }
            .font(.system(size: 16))
            
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(value)")
                    .font(.system(size: 28, weight: .bold))
                Text(unit)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black)
                .shadow(color: .red.opacity(0.3), radius: 5, x: 0, y: 2)
        )
    }
}

#Preview {
    ContentView()
}
