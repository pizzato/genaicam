import SwiftUI

struct ModelDownloadView: View {
    @Binding var needsModelDownload: Bool
    @StateObject private var model = FastVLMModel()
    @State private var isDownloading = false
    @StateObject private var diffusionManager = StableDiffusionModelManager()
    @State private var currentPhase: DownloadPhase?
    @State private var errorMessage: String?

    enum DownloadPhase {
        case fastVLM
        case stableDiffusion
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("On first launch, download Apple’s FastVLM (~1.1 GB) and Stable Diffusion (~2.5 GB) models. This one-time setup enables offline descriptions and image generation. Please use Wi‑Fi.")
                .multilineTextAlignment(.center)
                .padding()
            VStack(alignment: .leading, spacing: 16) {
                statusRow(
                    title: "FastVLM",
                    message: fastVLMStatus,
                    ready: FastVLMModel.modelExists()
                )
                statusRow(
                    title: "Stable Diffusion",
                    message: stableDiffusionStatus,
                    ready: StableDiffusionModelManager.modelExists()
                )
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(12)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            if isDownloading {
                if let progress = currentProgress {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                }
                let message = currentStatusMessage
                if !message.isEmpty {
                    Text(message)
                }
            } else {
                Button("Download Models") {
                    startDownload()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            if model.modelInfo.isEmpty {
                model.modelInfo = fastVLMStatus
            }
            diffusionManager.refreshStatus()
        }
    }

    private var fastVLMStatus: String {
        if isDownloading, currentPhase == .fastVLM, !model.modelInfo.isEmpty {
            return model.modelInfo
        }
        return FastVLMModel.modelExists() ? "FastVLM model ready" : "FastVLM model required (~1.1 GB)"
    }

    private var stableDiffusionStatus: String {
        if isDownloading, currentPhase == .stableDiffusion, !diffusionManager.modelInfo.isEmpty {
            return diffusionManager.modelInfo
        }
        return StableDiffusionModelManager.modelExists() ? "Stable Diffusion model ready" : diffusionManager.modelInfo
    }

    private var currentProgress: Double? {
        switch currentPhase {
        case .fastVLM:
            return model.downloadProgress
        case .stableDiffusion:
            return diffusionManager.downloadProgress
        case .none:
            return nil
        }
    }

    private var currentStatusMessage: String {
        switch currentPhase {
        case .fastVLM:
            return model.modelInfo
        case .stableDiffusion:
            return diffusionManager.modelInfo
        case .none:
            return ""
        }
    }

    private func statusRow(title: String, message: String, ready: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: ready ? "checkmark.circle.fill" : "icloud.and.arrow.down")
                .foregroundStyle(ready ? .green : .blue)
                .imageScale(.large)
        }
    }

    private func startDownload() {
        isDownloading = true
        errorMessage = nil
        currentPhase = nil

        Task {
            if !FastVLMModel.modelExists() {
                await MainActor.run { currentPhase = .fastVLM }
                let success = await model.download()
                guard success else {
                    await MainActor.run {
                        isDownloading = false
                        currentPhase = nil
                        errorMessage = "Unable to download FastVLM. Check your connection and try again."
                    }
                    return
                }
            }

            if !StableDiffusionModelManager.modelExists() {
                await MainActor.run { currentPhase = .stableDiffusion }
                let success = await diffusionManager.download()
                guard success else {
                    await MainActor.run {
                        isDownloading = false
                        currentPhase = nil
                        errorMessage = "Unable to download Stable Diffusion. Check your connection and try again."
                    }
                    return
                }
            }

            await MainActor.run {
                diffusionManager.refreshStatus()
                model.modelInfo = "FastVLM model ready"
                isDownloading = false
                currentPhase = nil
                needsModelDownload = false
            }
        }
    }
}

#Preview {
    ModelDownloadView(needsModelDownload: .constant(true))
}
