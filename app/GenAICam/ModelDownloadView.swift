import SwiftUI

struct ModelDownloadView: View {
    @Binding var needsModelDownload: Bool
    @State private var model = FastVLMModel()
    @State private var isDownloading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("On first run, we need to download Apple's FastVLM model, this is the only time the internet has to be accessed. The model is slightly above 1GB, make sure you use WiFi")
                .multilineTextAlignment(.center)
                .padding()
            if isDownloading {
                ProgressView(value: model.downloadProgress)
                    .padding()
                Text(model.modelInfo)
            }
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
            .disabled(isDownloading)
        }
        .padding()
    }
}

#Preview {
    ModelDownloadView(needsModelDownload: .constant(true))
}
