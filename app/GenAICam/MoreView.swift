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

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "GenAICam"
    }

    var body: some View {
        NavigationStack {
            
            Form {
                Button("About " + appName) { showWelcome = true }
                
                if !shortDescription.isEmpty {
                    Section("Short Description") {
                        Text(shortDescription)
                            .textSelection(.enabled)
                        HStack {
                            Button("") { copy(shortDescription) }
                            ShareLink(item: shortDescription) {
                                Label("Copy and Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
                if !longDescription.isEmpty {
                    Section("Long Description") {
                        Text(longDescription)
                            .textSelection(.enabled)
                        HStack {
                            Button("") { copy(longDescription) }
                            ShareLink(item: longDescription) {
                                Label("Copy and Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
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
