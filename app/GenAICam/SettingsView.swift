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
    @Binding var stableDiffusionStrength: Double
    @Binding var stableDiffusionPromptSuffix: String
    @Binding var stableDiffusionStartMode: StableDiffusionStartMode
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
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Steps")
                                Spacer()
                                Text("\(stableDiffusionStepCount)")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(stableDiffusionStepCount) },
                                    set: { stableDiffusionStepCount = Int($0.rounded()) }
                                ),
                                in: 10...50,
                                step: 1
                            )
                            Text("More steps produce finer details but take longer to generate.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Guidance")
                                Spacer()
                                Text(String(format: "%.1f", stableDiffusionGuidance))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(
                                value: $stableDiffusionGuidance,
                                in: 1...15,
                                step: 0.5
                            )
                            Text("Higher guidance keeps results closer to the description while lower values allow more variety.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Photo influence")
                                Spacer()
                                Text(String(format: "%.2f", stableDiffusionStrength))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(
                                value: $stableDiffusionStrength,
                                in: 0.0...1.0,
                                step: 0.05
                            )
                            Text("Higher values keep the output closer to the captured photo, while lower values allow the model to diverge.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Picker("Start from", selection: $stableDiffusionStartMode) {
                            ForEach(StableDiffusionStartMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(stableDiffusionStartMode.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
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
        stableDiffusionStepCount: .constant(25),
        stableDiffusionGuidance: .constant(7.5),
        stableDiffusionStrength: .constant(0.5),
        stableDiffusionPromptSuffix: .constant("photo, high quality, 8k"),
        stableDiffusionStartMode: .constant(.photo),
        mode: .constant(.short),
        isRealTime: .constant(false),
        showDescription: .constant(false),
        isImagePlaygroundAvailable: true
    )
}
