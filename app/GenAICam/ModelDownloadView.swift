import SwiftUI

struct ModelDownloadView: View {
    @Binding var needsModelDownload: Bool
    @StateObject private var model = FastVLMModel()
    @StateObject private var sdModel = StableDiffusionGenerator()
    @State private var isDownloading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Download the required models to enable offline features. This will fetch Apple’s FastVLM (~1.1 GB) for descriptions and the Core ML Stable Diffusion 2.1 model (~4.5 GB) for image generation. Please use Wi‑Fi.")
                .multilineTextAlignment(.center)
                .padding()
            if isDownloading {
                VStack {
                    VStack {
                        Text("FastVLM")
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
                    }
                    VStack {
                        Text("Stable Diffusion")
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
                }
            } else {
                VStack {
                    Text("FastVLM: \(model.modelInfo)")
                    Text("Stable Diffusion: \(sdModel.status)")
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
