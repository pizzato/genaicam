import SwiftUI

struct ModelDownloadView: View {
    @Binding var needsModelDownload: Bool
    @StateObject private var vlmModel = FastVLMModel()
    @StateObject private var sdModel = StableDiffusionModel()
    @State private var isDownloading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("On this first run, press Download to get required models (FastVLM and Stable Diffusion). This one-time setup enables offline image descriptions and generation. Please use Wi-Fi.")
                .multilineTextAlignment(.center)
                .padding()
            if isDownloading {
                if let progress = vlmModel.downloadProgress ?? sdModel.downloadProgress {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .padding()
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .padding()
                }
                if !vlmModel.modelInfo.isEmpty && sdModel.downloadProgress == nil {
                    Text(vlmModel.modelInfo)
                } else {
                    Text(sdModel.modelInfo)
                }
            } else {
                Text(vlmModel.modelInfo + "\n" + sdModel.modelInfo)
                    .multilineTextAlignment(.center)
                Button("Download Models") {
                    isDownloading = true
                    Task {
                        let vlmSuccess = await vlmModel.download()
                        let sdSuccess = await sdModel.download()
                        if vlmSuccess && sdSuccess {
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
