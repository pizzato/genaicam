//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import CoreImage
import FastVLM
import Foundation
import MLX
import MLXLMCommon
import MLXRandom
import MLXVLM
#if canImport(ZIPFoundation)
import ZIPFoundation
#endif
import Combine
import SwiftUI

@MainActor
class FastVLMModel: ObservableObject {

    @Published public var running = false
    @Published public var modelInfo = ""
    @Published public var output = ""
    @Published public var promptTime: String = ""
    @Published public var downloadProgress: Double? = nil

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    private let modelDirectory: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("FastVLM/model", isDirectory: true)
    }()

    private let modelIdentifier = "llava-fastvithd_0.5b_stage3_llm.fp16"
    private var modelDownloadURL: URL {
        URL(string: "https://ml-site.cdn-apple.com/datasets/fastvlm/\(modelIdentifier).zip")!
    }

    private var modelConfiguration: ModelConfiguration {
        FastVLM.modelConfiguration
    }

    /// parameters controlling the output
    let generateParameters = GenerateParameters(temperature: 0.0)
    let maxTokens = 240

    /// update the display every N tokens -- 4 looks like it updates continuously
    /// and is low overhead.  observed ~15% reduction in tokens/s when updating
    /// on every token
    let displayEveryNTokens = 4

    private var loadState = LoadState.idle
    private var currentTask: Task<Void, Never>?

    enum EvaluationState: String, CaseIterable {
        case idle = "Idle"
        case processingPrompt = "Processing Prompt"
        case generatingResponse = "Generating Response"
    }

    @Published public var evaluationState = EvaluationState.idle

    public init() {
        FastVLM.register(modelFactory: VLMModelFactory.shared)
    }

    static func modelExists() -> Bool {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let config = support.appendingPathComponent("FastVLM/model/config.json")
        return FileManager.default.fileExists(atPath: config.path)
    }

    /// Downloads the model archive if it is not already cached.
    /// - Returns: `true` on success, `false` if an error occurred.
    public func download() async -> Bool {
        await MainActor.run {
            withAnimation(.linear) {
                self.downloadProgress = 0
            }
            self.modelInfo = "Downloading..."
        }

        print("[FastVLM] Starting model download from \(modelDownloadURL.absoluteString)")
        do {
            try await ensureModelAvailable()
            await MainActor.run {
                self.modelInfo = "Download complete"
                self.downloadProgress = 1.0
            }
            print("[FastVLM] Model download and extraction finished")
            return true
        } catch {
            print("[FastVLM] Model download failed: \(error.localizedDescription)")
            await MainActor.run {
                self.modelInfo = "Error downloading model: \(error.localizedDescription)"
            }
            return false
        }
    }

    private func ensureModelAvailable() async throws {
        let configURL = modelDirectory.appendingPathComponent("config.json")
        if FileManager.default.fileExists(atPath: configURL.path) { return }

        let fm = FileManager.default
        try fm.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
            let progressHandler: (Double?) -> Void
            init(progressHandler: @escaping (Double?) -> Void) { self.progressHandler = progressHandler }

            func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                            didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                            totalBytesExpectedToWrite: Int64) {
                if totalBytesExpectedToWrite > 0 {
                    let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                    progressHandler(progress)
                } else {
                    progressHandler(nil)
                }
            }

            func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                            didFinishDownloadingTo location: URL) {
                // Required by URLSessionDownloadDelegate; handled by async API.
            }
        }

        let delegate = DownloadDelegate { progress in
            if let progress {
                print(String(format: "[FastVLM] Download progress: %.0f%%", progress * 100))
            } else {
                print("[FastVLM] Downloading model (progress unavailable)")
            }
            Task { @MainActor in
                if let progress {
                    withAnimation(.linear) {
                        self.downloadProgress = progress
                    }
                    self.modelInfo = "Downloading \(Int(progress * 100))%"
                } else {
                    withAnimation(.linear) {
                        self.downloadProgress = nil
                    }
                    self.modelInfo = "Downloading..."
                }
            }
        }

        let session = URLSession(configuration: .default)

        // Temporary workspace
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let (downloadedURL, _) = try await session.download(from: modelDownloadURL, delegate: delegate)
        print("[FastVLM] Downloaded archive to \(downloadedURL.path)")
        let zipURL = tempDir.appendingPathComponent("model.zip")
        try fm.moveItem(at: downloadedURL, to: zipURL)

        await MainActor.run {
            withAnimation(.linear) {
                self.downloadProgress = 0
            }
            self.modelInfo = "Extracting 0%"
        }
        print("[FastVLM] Extracting archive...")
        try await unzipItem(at: zipURL, to: tempDir) { progress in
            print(String(format: "[FastVLM] Extraction progress: %.0f%%", progress * 100))
            Task { @MainActor in
                withAnimation(.linear) {
                    self.downloadProgress = progress
                }
                self.modelInfo = "Extracting \(Int(progress * 100))%"
            }
        }
        print("[FastVLM] Extraction complete")

        await MainActor.run {
            self.modelInfo = "Finalizing..."
            self.downloadProgress = nil
        }

        // Copy extracted contents (which reside under modelIdentifier) to modelDirectory
        let extractedRoot = tempDir.appendingPathComponent(modelIdentifier, isDirectory: true)
        let files = try fm.contentsOfDirectory(at: extractedRoot, includingPropertiesForKeys: nil)
        for file in files {
            let dest = modelDirectory.appendingPathComponent(file.lastPathComponent)
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.moveItem(at: file, to: dest)
        }
        print("[FastVLM] Copied model files to cache at \(modelDirectory.path)")
    }

    private func unzipItem(at sourceURL: URL, to destinationURL: URL,
                           progressHandler: @escaping (Double) -> Void) async throws {
        #if canImport(ZIPFoundation)
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
                    print("[FastVLM] Unzipped archive using ZIPFoundation")
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        #else
        print("[FastVLM] ZIPFoundation not available for extraction")
        throw NSError(
            domain: "FastVLMModel",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "ZIPFoundation not available"]
        )
        #endif
    }

    private func _load() async throws -> ModelContainer {
        switch loadState {
        case .idle:
            // limit the buffer cache
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            try await ensureModelAvailable()

            let modelContainer = try await VLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            ) {
                [modelConfiguration] progress in
                Task { @MainActor in
                    self.modelInfo =
                        "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                }
            }
            self.modelInfo = "Loaded"
            loadState = .loaded(modelContainer)
            return modelContainer

        case .loaded(let modelContainer):
            return modelContainer
        }
    }

    public func load() async {
        do {
            _ = try await _load()
        } catch {
            self.modelInfo = "Error loading model: \(error)"
        }
    }

    public func generate(_ userInput: UserInput, stream: Bool = true) async -> Task<Void, Never> {
        if let currentTask, running {
            return currentTask
        }

        running = true
        
        // Cancel any existing task
        currentTask?.cancel()

        // Create new task and store reference
        let task = Task {
            do {
                let modelContainer = try await _load()

                // each time you generate you will get something new
                MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
                
                // Check if task was cancelled
                if Task.isCancelled { return }

                let result = try await modelContainer.perform { context in
                    // Measure the time it takes to prepare the input
                    
                    Task { @MainActor in
                        evaluationState = .processingPrompt
                    }

                    let llmStart = Date()
                    let input = try await context.processor.prepare(input: userInput)
                    
                    var seenFirstToken = false

                    // FastVLM generates the output
                    let result = try MLXLMCommon.generate(
                        input: input, parameters: generateParameters, context: context
                    ) { tokens in
                        // Check if task was cancelled
                        if Task.isCancelled {
                            return .stop
                        }

                        if !seenFirstToken {
                            seenFirstToken = true
                            
                            // produced first token, update the time to first token,
                            // the processing state and start displaying the text
                            let llmDuration = Date().timeIntervalSince(llmStart)
                            let text = context.tokenizer.decode(tokens: tokens)
                            Task { @MainActor in
                                evaluationState = .generatingResponse
                                self.promptTime = "\(Int(llmDuration * 1000)) ms"
                                if stream {
                                    self.output = text
                                }
                            }
                        }

                        // Show the text in the view as it generates
                        if stream && tokens.count % displayEveryNTokens == 0 {
                            let text = context.tokenizer.decode(tokens: tokens)
                            Task { @MainActor in
                                self.output = text
                            }
                        }

                        if tokens.count >= maxTokens {
                            return .stop
                        } else {
                            return .more
                        }
                    }
                    
                    // Return the duration of the LLM and the result
                    return result
                }
                
                // Check if task was cancelled before updating UI
                if !Task.isCancelled {
                    self.output = result.output
                }

            } catch {
                if !Task.isCancelled {
                    output = "Failed: \(error)"
                }
            }

            if evaluationState == .generatingResponse {
                evaluationState = .idle
            }

            running = false
        }
        
        currentTask = task
        return task
    }
    
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        running = false
        output = ""
        promptTime = ""
    }
}
