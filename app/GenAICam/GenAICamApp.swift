//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI

@main
struct GenAICamApp: App {
    @State private var needsModelDownload = !(FastVLMModel.modelExists() && StableDiffusionModelManager.modelExists())
#if os(iOS)
    @State private var isImagePlaygroundAvailable = false
#endif

    var body: some Scene {
        WindowGroup {
            Group {
                if needsModelDownload {
                    ModelDownloadView(needsModelDownload: $needsModelDownload)
                } else {
#if os(iOS)
                    ContentView(isImagePlaygroundAvailable: isImagePlaygroundAvailable)
#else
                    ContentView()
#endif
                }
            }
            .task {
#if os(iOS)
                await checkPlaygroundAvailability()
#endif
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
            isImagePlaygroundAvailable = available
        } else {
            isImagePlaygroundAvailable = false
        }
#else
        isImagePlaygroundAvailable = false
#endif
#endif
    }
}
