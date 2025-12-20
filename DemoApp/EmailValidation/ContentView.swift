//
//  ContentView.swift
//  EmailValidation
//
//  Created by Dave Poirier on 2025-12-20.
//

import SwiftUI

/// Root content view with navigation
struct ContentView: View {
    @StateObject private var store = TestDataStore()

    var body: some View {
        NavigationStack {
            SummaryView(store: store)
                .navigationDestination(for: ValidationMethod.self) { method in
                    CategoryListView(store: store, filterMethod: method)
                }
                .navigationDestination(for: String.self) { _ in
                    CategoryListView(store: store, filterMethod: nil)
                }
                .navigationDestination(for: TestCategory.self) { category in
                    CategoryDetailView(store: store, category: category)
                }
                .navigationDestination(for: ValidationResult.self) { result in
                    TestCaseDetailView(result: result)
                }
        }
    }
}

#Preview {
    ContentView()
}
