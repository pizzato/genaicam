//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI

@main
struct GenAICamApp: App {
    @State private var needsModelDownload = !(FastVLMModel.modelExists() && StableDiffusionGenerator.modelExists())

    var body: some Scene {
        WindowGroup {
            if needsModelDownload {
                ModelDownloadView(needsModelDownload: $needsModelDownload)
            } else {
                ContentView()
            }
        }
    }
}
