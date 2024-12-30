//
//  DemoView.swift
//  FightClub
//
//  Created by Edward Lee on 12/25/24.
//

import Foundation
import SwiftUI

struct DemoView: View {
    @StateObject private var viewModel: DemoViewModel
    
    init(viewModel: DemoViewModel = DIContainer.shared.makeDemoViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                List(viewModel.items) { item in
                    UserView(item: item)
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
//            await viewModel.fetchItems()
        }
    }
}


