//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI

@main
struct GenAICamApp: App {
    @State private var needsModelDownload = !(FastVLMModel.modelExists() && StableDiffusionModelManager.modelExists())
    @State private var showPlaygroundWarning = false

    var body: some Scene {
        WindowGroup {
            Group {
                if needsModelDownload {
                    ModelDownloadView(needsModelDownload: $needsModelDownload)
                } else {
                    ContentView()
                }
            }
            .task {
#if os(iOS)
                await checkPlaygroundAvailability()
#endif
            }
            .alert(
                "Image Playground Unavailable",
                isPresented: $showPlaygroundWarning
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(
                    "Apple Image Playground is not installed or enabled. Image generation on device will not work; only image descriptions will be available."
                )
            }
        }
    }

    @MainActor
    func checkPlaygroundAvailability() async {
#if os(iOS)
#if canImport(ImagePlayground)
        if #available(iOS 18.0, *) {
            let generator = PlaygroundImageGenerator()
            let available = await generator.isImagePlaygroundAvailable()
            if !available {
                showPlaygroundWarning = true
            }
        } else {
            showPlaygroundWarning = true
        }
#else
        showPlaygroundWarning = true
#endif
#endif
    }
}
