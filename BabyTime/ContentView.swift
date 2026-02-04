//
//  ContentView.swift
//  BabyTime
//
//  Created by Patrick McKowen on 1/27/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: 0) {
                HomeView(scenario: .preview)
            } label: {
                Image(systemName: "house.fill")
            }

            Tab(value: 1) {
                LogPlaceholderView()
            } label: {
                Image(systemName: "list.bullet")
            }

            Tab(value: 2) {
                AddPlaceholderView()
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}

// MARK: - Placeholder Views

private struct LogPlaceholderView: View {
    var body: some View {
        ZStack {
            BTColors.surfacePage.ignoresSafeArea()
            Text("Log")
                .font(BTTypography.label)
                .foregroundStyle(BTColors.textSecondary)
        }
    }
}

private struct AddPlaceholderView: View {
    var body: some View {
        ZStack {
            BTColors.surfacePage.ignoresSafeArea()
            Text("Add")
                .font(BTTypography.label)
                .foregroundStyle(BTColors.textSecondary)
        }
    }
}

#Preview {
    ContentView()
}
