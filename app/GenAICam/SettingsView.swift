//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var style: PlaygroundStyle
    @Binding var mode: DescriptionMode
    @Binding var isRealTime: Bool
    @Binding var showDescription: Bool
    @Binding var generator: ImageGenerationMode
    @State private var showWelcome = false
    
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "GenAICam"
    }
    
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
                }

                Section("Image Generator") {
                    Picker("Generator", selection: $generator) {
                        ForEach(ImageGenerationMode.allCases) { option in
                            switch option {
                            case .playground:
                                Text("Image Playground").tag(option)
                            case .stableDiffusion:
                                Text("Stable Diffusion").tag(option)
                            }
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if generator == .playground {
                    Section("Image Style") {
                        Picker("Style", selection: $style) {
                            ForEach(PlaygroundStyle.allCases) { option in
                                Text(option.rawValue.capitalized).tag(option)
                            }
                        }
                    }
                }


                Button("About " + appName) { showWelcome = true }
            }
            .navigationTitle("Settings")
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
}

#Preview {
    SettingsView(style: .constant(.sketch), mode: .constant(.short), isRealTime: .constant(false), showDescription: .constant(false), generator: .constant(.stableDiffusion))
}
