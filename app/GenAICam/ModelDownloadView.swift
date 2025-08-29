import SwiftUI

struct ModelDownloadView: View {
    @Binding var needsModelDownload: Bool
    @StateObject private var model = FastVLMModel()
    @State private var isDownloading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("On this first run, press Download to get Apple’s FastVLM model (~1.1 GB). This one-time setup enables offline image descriptions and is the only time the app needs internet. Please use Wi-Fi.")
                .multilineTextAlignment(.center)
                .padding()
            if isDownloading {
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
            } else {
                Text(model.modelInfo)
                Button("Download Model") {
                    isDownloading = true
                    Task {
                        let success = await model.download()
                        if success {
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
