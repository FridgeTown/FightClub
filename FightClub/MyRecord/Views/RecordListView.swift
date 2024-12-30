//
//  RecordListView.swift
//  FightClub
//
//  Created by Edward Lee on 12/29/24.
//

import SwiftUI
import CoreData

struct RecordListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BoxingSession.date, ascending: false)],
        animation: .default)
    private var sessions: FetchedResults<BoxingSession>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionRowView(session: session)
                    }
                }
                .onDelete(perform: deleteSessions)
            }
            .navigationTitle("복싱 기록")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: RecordingView()) {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                }
            }
        }
    }
    
    private func deleteSessions(offsets: IndexSet) {
        withAnimation {
            offsets.map { sessions[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting session: \(error)")
            }
        }
    }
}

struct SessionRowView: View {
    let session: BoxingSession
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(session.date, style: .date)
                .font(.headline)
            HStack {
                Label("\(session.punchCount) 펀치", systemImage: "hand.raised.fill")
                Spacer()
                Text(String(format: "%.1f분", session.duration / 60))
                    .foregroundColor(.secondary)
            }
            if let memo = session.memo {
                Text(memo)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
