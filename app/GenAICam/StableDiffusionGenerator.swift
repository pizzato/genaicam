//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import CoreML
import Foundation
#if os(iOS)
import UIKit
#if canImport(StableDiffusion)
import StableDiffusion
#endif

@available(iOS 17.0, *)
@MainActor
final class StableDiffusionGenerator: ObservableObject {
    enum GenerationError: LocalizedError {
        case modelMissing

        var errorDescription: String? {
            switch self {
            case .modelMissing:
                return "Stable Diffusion model not found. Download it from the setup screen."
            }
        }
    }

    @Published var isGenerating = false

    private var currentTask: Task<UIImage?, Error>?

#if canImport(StableDiffusion)
    private var pipeline: StableDiffusionPipeline?
#endif

    func generate(
        prompt: String,
        stepCount: Int,
        guidanceScale: Float,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> UIImage? {
        cancelGeneration()
        let safeStepCount = max(stepCount, 1)
        isGenerating = true
        progress(0, safeStepCount)

#if canImport(StableDiffusion)
        guard StableDiffusionModelManager.modelExists() else {
            isGenerating = false
            throw GenerationError.modelMissing
        }

        let pipeline = try await loadPipeline()

        let task = Task.detached(priority: .userInitiated) { [weak self] () throws -> UIImage? in
            var configuration = StableDiffusionPipeline.Configuration(prompt: prompt)
            configuration.stepCount = safeStepCount
            configuration.guidanceScale = guidanceScale
            configuration.seed = UInt32.random(in: 1...UInt32.max)
            configuration.disableSafety = false
            configuration.schedulerType = .dpmSolverMultistepScheduler
            configuration.useDenoisedIntermediates = true

            var lastStep = -1
            let images = try pipeline.generateImages(configuration: configuration) { progressInfo in
                if Task.isCancelled { return false }
                if progressInfo.step != lastStep {
                    lastStep = progressInfo.step
                    Task { @MainActor in
                        progress(progressInfo.step, progressInfo.stepCount)
                        self?.isGenerating = true
                    }
                }
                return true
            }

            guard let cgImage = images.compactMap({ $0 }).first else {
                return nil
            }

            #if os(iOS)
            return UIImage(cgImage: cgImage)
            #else
            return nil
            #endif
        }

        currentTask = task

        do {
            let image = try await task.value
            isGenerating = false
            currentTask = nil
            return image
        } catch {
            isGenerating = false
            currentTask = nil
            if Task.isCancelled { return nil }
            throw error
        }
#else
        isGenerating = false
        throw GenerationError.modelMissing
#endif
    }

    func cancelGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

#if canImport(StableDiffusion)
    private func loadPipeline() async throws -> StableDiffusionPipeline {
        if let pipeline { return pipeline }

        let resourcesURL = StableDiffusionModelManager.modelDirectory
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        let pipeline = try StableDiffusionPipeline(
            resourcesAt: resourcesURL,
            controlNet: [],
            configuration: configuration,
            disableSafety: false,
            reduceMemory: true
        )
        try pipeline.loadResources()
        self.pipeline = pipeline
        return pipeline
    }
#endif
}
#endif
