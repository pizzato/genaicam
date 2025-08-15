//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MoreView: View {
    @Environment(\.dismiss) private var dismiss
    let shortDescription: String
    let longDescription: String
    @State private var showWelcome = false

    var body: some View {
        NavigationStack {
            Form {
                if !shortDescription.isEmpty {
                    Section("Short Description") {
                        Text(shortDescription)
                            .textSelection(.enabled)
                        HStack {
                            Button("Copy") { copy(shortDescription) }
                            ShareLink(item: shortDescription) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
                if !longDescription.isEmpty {
                    Section("Long Description") {
                        Text(longDescription)
                            .textSelection(.enabled)
                        HStack {
                            Button("Copy") { copy(longDescription) }
                            ShareLink(item: longDescription) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
                Section("About") {
                    Button("Welcome Screen") { showWelcome = true }
                }
            }
            .navigationTitle("More")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showWelcome) {
                WelcomeView()
            }
        }
    }

    func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #endif
    }
}

#Preview {
    MoreView(shortDescription: "", longDescription: "")
}
