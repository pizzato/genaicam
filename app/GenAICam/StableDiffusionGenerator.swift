//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
import SwiftUI
import CoreML
#if canImport(StableDiffusion)
import StableDiffusion
#endif
#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

/// Wrapper around a Core ML Stable Diffusion pipeline.
@MainActor
class StableDiffusionGenerator: ObservableObject {
    @Published var downloadProgress: Double? = nil
    @Published var status: String = ""

    private let modelDirectory: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("StableDiffusion/model", isDirectory: true)
    }()

    private let modelArchiveURL = URL(string: "https://huggingface.co/apple/coreml-stable-diffusion-2-1-base-palettized/resolve/main/coreml-stable-diffusion-2-1-base-palettized_split_einsum_v2_compiled.zip")!

    /// Returns true if the model resources are already available on disk.
    static func modelExists() -> Bool {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let config = support.appendingPathComponent("StableDiffusion/model")
        return FileManager.default.fileExists(atPath: config.path)
    }

    /// Downloads and unpacks the Stable Diffusion resources if needed.
    func downloadModel() async -> Bool {
        let fm = FileManager.default
        let modelPath = modelDirectory.path
        if fm.fileExists(atPath: modelPath) {
            status = "Model ready"
            downloadProgress = 1.0
            return true
        }

        status = "Downloading..."
        downloadProgress = 0

        do {
            try fm.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
            let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: tempDir) }

            let zipURL = tempDir.appendingPathComponent("model.zip")
            let downloader = DownloadDelegate()
            try await downloader.download(from: modelArchiveURL, to: zipURL) { received, expected in
                let progress = expected > 0 ? Double(received) / Double(expected) : nil
                Task { @MainActor in
                    if let progress { self.downloadProgress = progress; self.status = String(format: "Downloading %d%%", Int(progress * 100)) }
                }
            }

            #if canImport(ZIPFoundation)
            try fm.unzipItem(at: zipURL, to: modelDirectory)
            #endif

            await MainActor.run {
                self.status = "Download complete"
                self.downloadProgress = 1.0
            }
            return true
        } catch {
            await MainActor.run {
                self.status = "Download failed"
                self.downloadProgress = nil
            }
            return false
        }
    }

    /// Generates an image for the given text prompt.
    /// - Parameters:
    ///   - prompt: Text prompt describing the desired image.
    ///   - progress: Called with the current step and total step count.
    /// - Returns: Generated image or nil on failure.
    func generate(prompt: String, progress: @escaping (Int, Int) -> Void) async -> UIImage? {
        #if canImport(StableDiffusion)
        do {
            let resourcesURL = modelDirectory
            let pipeline = try StableDiffusionPipeline(resourcesAt: resourcesURL)
            pipeline.progressHandler = { step, stepCount in
                progress(step + 1, stepCount)
                return true
            }
            let images = try pipeline.generate(prompt: prompt, stepCount: 20, seed: UInt32.random(in: 0..<UInt32.max))
            return images.first
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    var progressHandler: ((Int64, Int64) -> Void)?
    var destinationURL: URL?
    private var continuation: CheckedContinuation<Void, Error>?
    private var session: URLSession?

    func download(from url: URL, to destinationURL: URL, progress: @escaping (Int64, Int64) -> Void) async throws {
        self.destinationURL = destinationURL
        self.progressHandler = progress
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        self.session = session
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progressHandler?(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            if let dest = destinationURL {
                let fm = FileManager.default
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.moveItem(at: location, to: dest)
            }
            continuation?.resume(returning: ())
        } catch {
            continuation?.resume(throwing: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { continuation?.resume(throwing: error) }
        session.invalidateAndCancel()
    }
}
