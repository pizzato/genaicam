import SwiftUI

struct ModelDownloadView: View {
    @Binding var needsModelDownload: Bool
    @StateObject private var model = FastVLMModel()
    @StateObject private var sdModel = StableDiffusionGenerator()
    @State private var isDownloading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("On this first run, press Download to get Apple’s FastVLM model (~1.1 GB) and the Stable Diffusion model. This one-time setup enables offline features and is the only time the app needs internet. Please use Wi-Fi.")
                .multilineTextAlignment(.center)
                .padding()
            if isDownloading {
                VStack {
                    if let progress = model.downloadProgress {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(.linear)
                            .padding()
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .padding()
                    }
                    Text(model.modelInfo)
                    if let progress = sdModel.downloadProgress {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(.linear)
                            .padding()
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .padding()
                    }
                    Text(sdModel.status)
                }
            } else {
                VStack {
                    Text(model.modelInfo)
                    Text(sdModel.status)
                }
                Button("Download Models") {
                    isDownloading = true
                    Task {
                        let successVLM = await model.download()
                        let successSD = await sdModel.downloadModel()
                        if successVLM && successSD {
                            needsModelDownload = false
                        } else {
                            isDownloading = false
                        }
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ModelDownloadView(needsModelDownload: .constant(true))
}
