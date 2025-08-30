//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
import SwiftUI
#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

@MainActor
class StableDiffusionModel: ObservableObject {
    @Published var modelInfo: String = ""
    @Published var downloadProgress: Double? = nil

    nonisolated(unsafe) static var modelDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("StableDiffusion/model", isDirectory: true)
    }

    static func modelExists() -> Bool {
        let fm = FileManager.default
        // A completion marker ensures the model isn't re-downloaded if the
        // archive had an unexpected layout.
        if fm.fileExists(atPath: modelDirectory.appendingPathComponent(".complete").path) {
            return true
        }
        guard let items = try? fm.contentsOfDirectory(at: modelDirectory,
                                                     includingPropertiesForKeys: nil,
                                                     options: [.skipsHiddenFiles]) else {
            return false
        }
        return items.contains { ["mlpackage", "mlmodelc"].contains($0.pathExtension) }
    }

    private var modelDownloadURL: URL {
        // Use the NE-optimized split_einsum_v2 variant of the palettized model
        URL(string: "https://huggingface.co/apple/coreml-stable-diffusion-2-1-base-palettized/resolve/main/coreml-stable-diffusion-2-1-base-palettized_split_einsum_v2_compiled.zip")!
    }

    func download() async -> Bool {
        await MainActor.run {
            withAnimation(.linear) { self.downloadProgress = 0 }
            self.modelInfo = "Downloading..."
        }

        print("[StableDiffusion] Starting model download from \(modelDownloadURL.absoluteString)")
        do {
            try await ensureModelAvailable()
            await MainActor.run {
                self.modelInfo = "Download complete"
                self.downloadProgress = 1.0
            }
            print("[StableDiffusion] Model download and extraction finished")
            return true
        } catch {
            print("[StableDiffusion] Model download failed: \(error.localizedDescription)")
            await MainActor.run { self.modelInfo = "Error: \(error.localizedDescription)" }
            return false
        }
    }

    private func ensureModelAvailable() async throws {
        if Self.modelExists() { return }

        let fm = FileManager.default
        try fm.createDirectory(at: Self.modelDirectory, withIntermediateDirectories: true)

        final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
            let progressHandler: (Double?) -> Void
            init(progressHandler: @escaping (Double?) -> Void) { self.progressHandler = progressHandler }
            func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                            didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                            totalBytesExpectedToWrite: Int64) {
                if totalBytesExpectedToWrite > 0 {
                    progressHandler(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
                } else {
                    progressHandler(nil)
                }
            }

            // Required by URLSessionDownloadDelegate but unused since the async
            // download method returns the temporary file URL directly.
            func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                            didFinishDownloadingTo location: URL) {}
        }

        let delegate = DownloadDelegate { progress in
            Task { @MainActor in
                if let progress {
                    withAnimation(.linear) { self.downloadProgress = progress }
                    self.modelInfo = "Downloading \(Int(progress * 100))%"
                } else {
                    self.modelInfo = "Downloading..."
                    self.downloadProgress = nil
                }
            }
        }

        let session = URLSession(configuration: .default)
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let (downloadedURL, _) = try await session.download(from: modelDownloadURL, delegate: delegate)
        print("[StableDiffusion] Downloaded archive to \(downloadedURL.path)")
        let zipURL = tempDir.appendingPathComponent("model.zip")
        try fm.moveItem(at: downloadedURL, to: zipURL)

        await MainActor.run {
            self.modelInfo = "Extracting 0%"
            self.downloadProgress = 0
        }
        print("[StableDiffusion] Extracting archive...")

        #if canImport(ZIPFoundation)
        let unzipProgress = Progress(totalUnitCount: 100)
        let observation = unzipProgress.observe(\.fractionCompleted) { progress, _ in
            let fraction = progress.fractionCompleted
            print(String(format: "[StableDiffusion] Extraction progress: %.0f%%", fraction * 100))
            Task { @MainActor in
                self.modelInfo = "Extracting \(Int(fraction * 100))%"
                self.downloadProgress = fraction
            }
        }
        try fm.unzipItem(at: zipURL, to: tempDir, progress: unzipProgress)
        observation.invalidate()
        print("[StableDiffusion] Extraction complete")
        #else
        throw NSError(domain: "StableDiffusionModel", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "ZIPFoundation not available"])
        #endif

        await MainActor.run {
            self.modelInfo = "Finalizing..."
            self.downloadProgress = nil
        }

        // Move the extracted model files into the cache directory. Some archives
        // have a single root folder while others contain the `.mlpackage` items
        // at the top level, so iterate over every item in the temp directory.
        let extractedItems = try fm.contentsOfDirectory(at: tempDir,
                                                       includingPropertiesForKeys: [.isDirectoryKey],
                                                       options: [.skipsHiddenFiles])
        for item in extractedItems {
            let name = item.lastPathComponent
            if name == "model.zip" || name == "__MACOSX" { continue }
            let dest = Self.modelDirectory.appendingPathComponent(name)
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.moveItem(at: item, to: dest)
        }
        // Mark completion so subsequent launches detect the cached model
        fm.createFile(atPath: Self.modelDirectory.appendingPathComponent(".complete").path, contents: nil)
        print("[StableDiffusion] Copied model files to cache at \(Self.modelDirectory.path)")
    }

}

