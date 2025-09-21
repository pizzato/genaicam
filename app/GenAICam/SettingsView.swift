//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var style: PlaygroundStyle
    @Binding var provider: ImageGeneratorProvider
    @Binding var stableDiffusionStepCount: Int
    @Binding var stableDiffusionGuidance: Double
    @Binding var stableDiffusionPromptSuffix: String
    @Binding var mode: DescriptionMode
    @Binding var isRealTime: Bool
    @Binding var showDescription: Bool
    @State private var showWelcome = false
    let isImagePlaygroundAvailable: Bool
    
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

                Section("Image Generation") {
                    Picker("Generator", selection: $provider) {
                        ForEach(ImageGeneratorProvider.allCases) { option in
                            Text(option.title)
                                .tag(option)
                                .foregroundStyle(option == .imagePlayground && !isImagePlaygroundAvailable ? .secondary : .primary)
                                .disabled(option == .imagePlayground && !isImagePlaygroundAvailable)
                        }
                    }
                    Text(provider.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)

                    if !isImagePlaygroundAvailable {
                        Text("Image Playground is not available on this device.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    switch provider {
                    case .imagePlayground:
                        if isImagePlaygroundAvailable {
                            Picker("Style", selection: $style) {
                                ForEach(PlaygroundStyle.allCases) { option in
                                    Text(option.rawValue.capitalized).tag(option)
                                }
                            }
                        }
                    case .stableDiffusion:
                        Picker("Steps", selection: $stableDiffusionStepCount) {
                            ForEach(StableDiffusionStepPreset.allCases) { preset in
                                Text(preset.label).tag(preset.rawValue)
                            }
                        }
                        Picker("Guidance", selection: $stableDiffusionGuidance) {
                            ForEach(StableDiffusionGuidancePreset.allCases) { preset in
                                Text(preset.label).tag(preset.rawValue)
                            }
                        }
                        TextField("Additional prompt text", text: $stableDiffusionPromptSuffix)
#if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
#endif
                        Text("Appended to the long description when generating Stable Diffusion images.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
    SettingsView(
        style: .constant(.sketch),
        provider: .constant(.stableDiffusion),
        stableDiffusionStepCount: .constant(StableDiffusionStepPreset.balanced.rawValue),
        stableDiffusionGuidance: .constant(StableDiffusionGuidancePreset.standard.rawValue),
        stableDiffusionPromptSuffix: .constant("photo, high quality, 8k"),
        mode: .constant(.short),
        isRealTime: .constant(false),
        showDescription: .constant(false),
        isImagePlaygroundAvailable: true
    )
}
