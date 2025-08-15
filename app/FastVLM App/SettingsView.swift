//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var style: PlaygroundStyle

    var body: some View {
        NavigationStack {
            Form {
                Section("Image Style") {
                    Picker("Style", selection: $style) {
                        ForEach(PlaygroundStyle.allCases) { option in
                            Text(option.rawValue.capitalized).tag(option)
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
}

#Preview {
    SettingsView(style: .constant(.sketch))
}
