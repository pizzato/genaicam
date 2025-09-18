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
final class StableDiffusionModelManager: ObservableObject {
    static let modelFolderName = "coreml-stable-diffusion-2-1-base-palettized_split_einsum_v2_compiled"

    @Published var modelInfo: String = ""
    @Published var downloadProgress: Double? = nil

    private let modelURL = URL(string: "https://huggingface.co/apple/coreml-stable-diffusion-2-1-base-palettized/resolve/main/coreml-stable-diffusion-2-1-base-palettized_split_einsum_v2_compiled.zip")!
    private var lastLoggedDownloadPercent: Int = -1
    private var lastLoggedExtractionPercent: Int = -1

    private static var rootDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("StableDiffusion", isDirectory: true)
    }

    static var modelDirectory: URL {
        rootDirectory.appendingPathComponent(modelFolderName, isDirectory: true)
    }

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        if Self.modelExists() {
            print("[StableDiffusion] Model already available at \(Self.modelDirectory.path)")
            modelInfo = "Stable Diffusion model ready"
            downloadProgress = 1.0
        } else {
            print("[StableDiffusion] Stable Diffusion model missing. Download required.")
            modelInfo = "Stable Diffusion 2.1 Base model required (~2.5 GB)"
            downloadProgress = nil
        }
    }

    static func modelExists() -> Bool {
        let directory = modelDirectory
        let encoderPackage = directory.appendingPathComponent("TextEncoder.mlpackage")
        let encoderModelc = directory.appendingPathComponent("TextEncoder.mlmodelc")
        return FileManager.default.fileExists(atPath: encoderPackage.path) ||
            FileManager.default.fileExists(atPath: encoderModelc.path)
    }

    func download() async -> Bool {
        if Self.modelExists() {
            print("[StableDiffusion] Download skipped because model already exists.")
            refreshStatus()
            return true
        }

        withAnimation(.linear) {
            downloadProgress = 0
        }
        modelInfo = "Downloading..."
        print("[StableDiffusion] Beginning model download from \(modelURL.absoluteString)")
        lastLoggedDownloadPercent = -1
        lastLoggedExtractionPercent = -1

        do {
            try await ensureModelAvailable()
            modelInfo = "Download complete"
            withAnimation(.linear) {
                downloadProgress = 1.0
            }
            print("[StableDiffusion] Model download and extraction finished successfully.")
            return true
        } catch {
            print("[StableDiffusion] Model download failed: \(error.localizedDescription)")
            modelInfo = "Error downloading model: \(error.localizedDescription)"
            withAnimation(.linear) {
                downloadProgress = nil
            }
            return false
        }
    }

    private func ensureModelAvailable() async throws {
        if Self.modelExists() { return }

        print("[StableDiffusion] Preparing directories for model deployment.")
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: Self.rootDirectory, withIntermediateDirectories: true)

        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        let zipURL = tempDir.appendingPathComponent("stable-diffusion.zip")
        let downloader = ModelDownloader()
        try await downloader.download(from: modelURL, to: zipURL) { received, expected in
            let megabyte = 1024.0 * 1024.0
            let writtenMB = Double(received) / megabyte
            let expectedMB = expected > 0 ? Double(expected) / megabyte : nil
            let progress = expected > 0 ? Double(received) / Double(expected) : nil

            Task { @MainActor in
                if let progress {
                    withAnimation(.linear) { self.downloadProgress = progress }
                    self.modelInfo = String(format: "Downloading %.0f%%", progress * 100)
                    let percent = Int(progress * 100)
                    if percent != self.lastLoggedDownloadPercent {
                        self.lastLoggedDownloadPercent = percent
                        if let expectedMB {
                            print(String(format: "[StableDiffusion] Download progress %d%% (%.1f/%.1f MB).", percent, writtenMB, expectedMB))
                        } else {
                            print(String(format: "[StableDiffusion] Download progress %d%% (%.1f MB downloaded).", percent, writtenMB))
                        }
                    }
                } else {
                    withAnimation(.linear) { self.downloadProgress = nil }
                    if let expectedMB {
                        self.modelInfo = String(format: "Downloading %.0f/%.0f MB", writtenMB, expectedMB)
                        print(String(format: "[StableDiffusion] Downloaded %.1f/%.1f MB.", writtenMB, expectedMB))
                    } else {
                        self.modelInfo = String(format: "Downloading %.0f MB", writtenMB)
                        print(String(format: "[StableDiffusion] Downloaded %.1f MB (total size unknown).", writtenMB))
                    }
                }
            }
        }

        withAnimation(.linear) {
            downloadProgress = 0
        }
        modelInfo = "Extracting 0%"
        print("[StableDiffusion] Download complete. Beginning extraction of archive at \(zipURL.path)")

        try await unzipItem(at: zipURL, to: tempDir) { progress in
            Task { @MainActor in
                withAnimation(.linear) { self.downloadProgress = progress }
                self.modelInfo = "Extracting \(Int(progress * 100))%"
                let percent = Int(progress * 100)
                if percent != self.lastLoggedExtractionPercent {
                    self.lastLoggedExtractionPercent = percent
                    print("[StableDiffusion] Extraction progress \(percent)%.")
                }
            }
        }

        let destination = Self.modelDirectory
        if fileManager.fileExists(atPath: destination.path) {
            print("[StableDiffusion] Removing existing model directory at \(destination.path)")
            try fileManager.removeItem(at: destination)
        }

        let extractedRoot = tempDir.appendingPathComponent(Self.modelFolderName, isDirectory: true)
        if fileManager.fileExists(atPath: extractedRoot.path) {
            print("[StableDiffusion] Moving extracted model to application support directory.")
            try fileManager.moveItem(at: extractedRoot, to: destination)
        } else {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for item in contents {
                let target = destination.appendingPathComponent(item.lastPathComponent)
                if fileManager.fileExists(atPath: target.path) {
                    try fileManager.removeItem(at: target)
                }
                print("[StableDiffusion] Moving \(item.lastPathComponent) to \(target.path)")
                try fileManager.moveItem(at: item, to: target)
            }
        }

        print("[StableDiffusion] Model files staged successfully at \(destination.path)")
        refreshStatus()
    }

    private func unzipItem(at sourceURL: URL, to destinationURL: URL,
                           progressHandler: @escaping (Double) -> Void) async throws {
#if canImport(ZIPFoundation)
        print("[StableDiffusion] Unzipping archive from \(sourceURL.path) to \(destinationURL.path)")
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let fileManager = FileManager.default
                    let archive = try Archive(url: sourceURL, accessMode: .read)
                    let entries = Array(archive)
                    let total = entries.count
                    for (index, entry) in entries.enumerated() {
                        let entryURL = destinationURL.appendingPathComponent(entry.path)
                        try fileManager.createDirectory(
                            at: entryURL.deletingLastPathComponent(),
                            withIntermediateDirectories: true
                        )
                        _ = try archive.extract(entry, to: entryURL)
                        progressHandler(Double(index + 1) / Double(total))
                    }
                    print("[StableDiffusion] Archive extraction completed successfully.")
                    continuation.resume(returning: ())
                } catch {
                    print("[StableDiffusion] Archive extraction failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
#else
        throw NSError(
            domain: "StableDiffusionModelManager",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "ZIPFoundation not available"]
        )
        #endif
    }
}
