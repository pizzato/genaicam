//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct PromptSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let shortDescription: String
    let longDescription: String
    @Binding var mode: DescriptionMode
    @Binding var isRealTime: Bool
    @Binding var liveDescription: String
    @Binding var showDescription: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Live Description") {
                    Toggle("Enabled", isOn: Binding(
                        get: { isRealTime },
                        set: {
                            isRealTime = $0
                            showDescription = $0
                        }
                    ))
                    Picker("Type", selection: $mode) {
                        Text("Short").tag(DescriptionMode.short)
                        Text("Long").tag(DescriptionMode.long)
                    }
                    .pickerStyle(.segmented)
                    Text(liveDescription)
                        .textSelection(.enabled)
                    HStack {
                        Button("Copy") { copy(liveDescription) }
                        ShareLink(item: liveDescription) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
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
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
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
    PromptSettingsView(
        shortDescription: "",
        longDescription: "",
        mode: .constant(.short),
        isRealTime: .constant(false),
        liveDescription: .constant(""),
        showDescription: .constant(false)
    )
}
