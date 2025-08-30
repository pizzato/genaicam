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

    static let modelIdentifier = "coreml-stable-diffusion-2-1-base-palettized"

    static var modelDirectory: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("StableDiffusion/model", isDirectory: true)
    }()

    static func modelExists() -> Bool {
        let unet = modelDirectory.appendingPathComponent("UnetPalettized.mlpackage")
        return FileManager.default.fileExists(atPath: unet.path)
    }

    private var modelDownloadURL: URL {
        URL(string: "https://huggingface.co/apple/coreml-stable-diffusion-2-1-base-palettized/resolve/main/\(Self.modelIdentifier).zip")!
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
        let marker = Self.modelDirectory.appendingPathComponent("UnetPalettized.mlpackage")
        if FileManager.default.fileExists(atPath: marker.path) { return }

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

        try await unzipItem(at: zipURL, to: tempDir) { progress in
            print(String(format: "[StableDiffusion] Extraction progress: %.0f%%", progress * 100))
            Task { @MainActor in
                self.modelInfo = "Extracting \(Int(progress * 100))%"
                self.downloadProgress = progress
            }
        }
        print("[StableDiffusion] Extraction complete")

        await MainActor.run {
            self.modelInfo = "Finalizing..."
            self.downloadProgress = nil
        }

        let extractedRoot = tempDir.appendingPathComponent(Self.modelIdentifier, isDirectory: true)
        let files = try fm.contentsOfDirectory(at: extractedRoot, includingPropertiesForKeys: nil)
        for file in files {
            let dest = Self.modelDirectory.appendingPathComponent(file.lastPathComponent)
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.moveItem(at: file, to: dest)
        }
        print("[StableDiffusion] Copied model files to cache at \(Self.modelDirectory.path)")
    }

    private func unzipItem(at sourceURL: URL, to destinationURL: URL,
                           progressHandler: @escaping (Double) -> Void) async throws {
        #if canImport(ZIPFoundation)
        do {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let fileManager = FileManager.default
                        let archive = try Archive(url: sourceURL, accessMode: .read)
                        let entries = Array(archive)
                        let total = entries.count
                        for (index, entry) in entries.enumerated() {
                            let entryURL = destinationURL.appendingPathComponent(entry.path)
                            try fileManager.createDirectory(at: entryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                            _ = try archive.extract(entry, to: entryURL)
                            progressHandler(Double(index + 1) / Double(total))
                        }
                        print("[StableDiffusion] Unzipped archive using ZIPFoundation")
                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            print("[StableDiffusion] ZIPFoundation unzip failed: \(error.localizedDescription). Falling back to FileManager unzip")
            if #available(iOS 16.0, macOS 13.0, *) {
                try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)
                progressHandler(1.0)
                print("[StableDiffusion] Unzipped archive using FileManager")
            } else {
                throw error
            }
        }
        #else
        if #available(iOS 16.0, macOS 13.0, *) {
            try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)
            progressHandler(1.0)
            print("[StableDiffusion] Unzipped archive using FileManager")
        } else {
            throw NSError(domain: "StableDiffusionModel", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "ZIPFoundation not available"])
        }
        #endif
    }
}

