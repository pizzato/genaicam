//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import CoreML
import Foundation
#if os(iOS)
import UIKit

@available(iOS 17.0, *)
extension StableDiffusionPipeline: @unchecked Sendable {}

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

    private static let defaultNegativePrompt = "ugly, deformed, disfigured, poor details, bad anatomy"

    private struct StartingImageConfiguration: @unchecked Sendable {
        let image: CGImage
        let strength: Float
    }

    private var currentTask: Task<UIImage?, Error>?
    private var pipeline: StableDiffusionPipeline?
    private let lowMemoryDevice: Bool
#if os(iOS)
    private var memoryWarningObserver: NSObjectProtocol?
#endif

    init() {
#if os(iOS)
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let gigabyte = 1024.0 * 1024.0 * 1024.0
        let memoryInGB = Double(physicalMemory) / gigabyte
        let lowMemoryThreshold = UInt64(8 * 1024 * 1024 * 1024)
        let isLowMemory = physicalMemory > 0 && physicalMemory < lowMemoryThreshold
        self.lowMemoryDevice = isLowMemory
        if isLowMemory {
            print(String(format: "[StableDiffusion] Low-memory device detected (~%.1f GB). Applying memory optimizations.", memoryInGB))
        }
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.handleMemoryWarning()
            }
        }
#else
        self.lowMemoryDevice = false
#endif
    }

    deinit {
#if os(iOS)
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
#endif
    }

    var isLowMemoryDevice: Bool {
        lowMemoryDevice
    }

    func generate(
        prompt: String,
        stepCount: Int,
        guidanceScale: Float,
        startMode: StableDiffusionStartMode,
        photoInfluence: Float,
        sourceImage: UIImage?,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> UIImage? {
        cancelGeneration()
        let safeStepCount = max(stepCount, 1)
        isGenerating = true
        progress(-1, safeStepCount)
        await Task.yield()
        let normalizedPhotoInfluence = max(0.0, min(photoInfluence, 1.0))
        let pipelineStrength: Float?
        let strengthDescription: String
        if startMode == .photo {
            let computedStrength = Self.pipelineStrength(
                forPhotoInfluence: normalizedPhotoInfluence,
                stepCount: safeStepCount
            )
            pipelineStrength = computedStrength
            strengthDescription = String(
                format: ", photo influence %.2f (pipeline strength %.2f)",
                Double(normalizedPhotoInfluence),
                Double(computedStrength)
            )
        } else {
            pipelineStrength = nil
            strengthDescription = ""
        }
        print("[StableDiffusion] Requested generation with prompt length \(prompt.count), \(safeStepCount) steps, guidance \(guidanceScale)\(strengthDescription).")

        guard StableDiffusionModelManager.modelExists() else {
            print("[StableDiffusion] Model missing when attempting generation.")
            isGenerating = false
            throw GenerationError.modelMissing
        }

        let pipeline = try await loadPipeline()
        print("[StableDiffusion] Pipeline ready. Launching generation task.")

        let startingConfiguration = startingImageConfiguration(
            for: pipeline,
            mode: startMode,
            photoInfluence: normalizedPhotoInfluence,
            strength: pipelineStrength,
            sourceImage: sourceImage
        )
        if startMode == .photo && startingConfiguration == nil {
            print("[StableDiffusion] Falling back to noise: unable to prepare starting image.")
        }

        let disableSafety = lowMemoryDevice
        let unloadPipelineAfterUse = lowMemoryDevice
        let task = Task.detached(priority: .userInitiated) { () async throws -> UIImage? in
            var configuration = StableDiffusionPipeline.Configuration(prompt: prompt)
            configuration.stepCount = safeStepCount
            configuration.guidanceScale = guidanceScale
            configuration.seed = UInt32.random(in: 1...UInt32.max)
            configuration.disableSafety = disableSafety
            configuration.schedulerType = .dpmSolverMultistepScheduler
            configuration.useDenoisedIntermediates = !unloadPipelineAfterUse
            configuration.negativePrompt = Self.defaultNegativePrompt
            if let startingConfiguration {
                configuration.startingImage = startingConfiguration.image
                configuration.strength = startingConfiguration.strength
            }

            var lastStep = -1
            defer {
                if unloadPipelineAfterUse {
                    pipeline.unloadResources()
                }
            }
            let images = try await pipeline.generateImages(configuration: configuration) { progressInfo in
                if Task.isCancelled { return false }
                if progressInfo.step != lastStep {
                    lastStep = progressInfo.step
                    Task { @MainActor in
                        let current = min(progressInfo.step + 1, progressInfo.stepCount)
                        progress(current, progressInfo.stepCount)
                    }
                    print("[StableDiffusion] Progress: step \(progressInfo.step + 1) of \(progressInfo.stepCount).")
                }
                return true
            }

            guard let cgImage = images.compactMap({ $0 }).first else {
                print("[StableDiffusion] Generation completed but no image was produced.")
                return nil
            }

#if os(iOS)
            print("[StableDiffusion] Generation completed successfully.")
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
            print("[StableDiffusion] Generation failed: \(error.localizedDescription)")
            throw error
        }
    }

    func cancelGeneration() {
        if currentTask != nil {
            print("[StableDiffusion] Cancelling active generation task.")
        }
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    private func loadPipeline() async throws -> StableDiffusionPipeline {
        if let pipeline {
            print("[StableDiffusion] Reusing cached pipeline instance.")
            return pipeline
        }

        let resourcesURL = StableDiffusionModelManager.modelDirectory
        let computeUnits: MLComputeUnits = .cpuAndNeuralEngine
        let disableSafetyChecker = lowMemoryDevice
        let shouldPrewarm = !lowMemoryDevice
        print("[StableDiffusion] Loading pipeline from \(resourcesURL.path) with compute units \(computeUnits).")
        if disableSafetyChecker {
            print("[StableDiffusion] Safety checker disabled to reduce memory footprint.")
        }
        if !shouldPrewarm {
            print("[StableDiffusion] Skipping pipeline prewarm due to memory constraints.")
        }
        let pipeline = try await Task.detached(priority: .userInitiated) { () throws -> StableDiffusionPipeline in
            let configuration = MLModelConfiguration()
            configuration.computeUnits = computeUnits
            let pipeline = try StableDiffusionPipeline(
                resourcesAt: resourcesURL,
                controlNet: [],
                configuration: configuration,
                disableSafety: disableSafetyChecker,
                reduceMemory: true
            )
            if shouldPrewarm {
                try pipeline.loadResources()
            }
            return pipeline
        }.value
        print("[StableDiffusion] Pipeline resources loaded into memory.")
        if lowMemoryDevice {
            print("[StableDiffusion] Not caching pipeline to keep memory usage low.")
        } else {
            self.pipeline = pipeline
        }
        return pipeline
    }

    private func handleMemoryWarning() {
        print("[StableDiffusion] Memory warning received. Releasing pipeline resources and cancelling generation.")
        cancelGeneration()
        pipeline?.unloadResources()
        pipeline = nil
    }

    private func startingImageConfiguration(
        for pipeline: StableDiffusionPipeline,
        mode: StableDiffusionStartMode,
        photoInfluence: Float,
        strength: Float?,
        sourceImage: UIImage?
    ) -> StartingImageConfiguration? {
        guard mode == .photo else { return nil }
        guard let strength else { return nil }
        guard let encoder = pipeline.encoder else {
            print("[StableDiffusion] Requested image-to-image mode but encoder is unavailable.")
            return nil
        }
        guard let sourceImage else {
            print("[StableDiffusion] Requested image-to-image mode without a source image.")
            return nil
        }
        let shape = encoder.inputShape
        guard shape.count == 4 else {
            print("[StableDiffusion] Unexpected encoder input shape: \(shape).")
            return nil
        }
        let targetWidth = shape[3]
        let targetHeight = shape[2]
        let targetSize = CGSize(width: CGFloat(targetWidth), height: CGFloat(targetHeight))
        guard let preparedImage = resizedCGImage(from: sourceImage, targetSize: targetSize) else {
            print("[StableDiffusion] Failed to resize source image for encoder input.")
            return nil
        }
        let clampedInfluence = max(0.0, min(photoInfluence, 1.0))
        let clampedStrength = max(0.0, min(strength, 1.0))
        let formattedInfluence = String(format: "%.2f", Double(clampedInfluence))
        let formattedStrength = String(format: "%.2f", Double(clampedStrength))
        print(
            "[StableDiffusion] Using captured photo as starting image (resized to \(targetWidth)x\(targetHeight), photo influence \(formattedInfluence), pipeline strength \(formattedStrength))."
        )
        return StartingImageConfiguration(image: preparedImage, strength: clampedStrength)
    }

    private static func pipelineStrength(forPhotoInfluence influence: Float, stepCount: Int) -> Float {
        let clampedInfluence = max(0.0, min(influence, 1.0))
        let inverted = 1.0 - clampedInfluence
        let maximumStrength: Float = 0.95
        let minimumStrengthFromSteps: Float
        if stepCount > 0 {
            minimumStrengthFromSteps = 1.0 / Float(stepCount)
        } else {
            minimumStrengthFromSteps = 0.01
        }
        let minimumStrength = max(minimumStrengthFromSteps, 0.01)
        let cappedStrength = min(inverted, maximumStrength)
        if minimumStrength >= maximumStrength {
            return minimumStrength
        }
        return max(cappedStrength, minimumStrength)
    }

    private func resizedCGImage(from image: UIImage, targetSize: CGSize) -> CGImage? {
        guard targetSize.width > 0, targetSize.height > 0 else {
            return nil
        }

        let targetAspectRatio = targetSize.width / targetSize.height
        var imageForResizing = image

        if targetAspectRatio > 0,
           let cgImage = image.cgImage {
            let originalWidth = CGFloat(cgImage.width)
            let originalHeight = CGFloat(cgImage.height)
            if originalWidth > 0, originalHeight > 0 {
                let originalAspectRatio = originalWidth / originalHeight
                if abs(originalAspectRatio - targetAspectRatio) > 0.001 {
                    var cropRect = CGRect(origin: .zero, size: CGSize(width: originalWidth, height: originalHeight))
                    if originalAspectRatio > targetAspectRatio {
                        let newWidth = originalHeight * targetAspectRatio
                        cropRect.origin.x = (originalWidth - newWidth) / 2.0
                        cropRect.size.width = newWidth
                    } else {
                        let newHeight = originalWidth / targetAspectRatio
                        cropRect.origin.y = (originalHeight - newHeight) / 2.0
                        cropRect.size.height = newHeight
                    }

                    if let croppedCGImage = cgImage.cropping(to: cropRect) {
                        imageForResizing = UIImage(
                            cgImage: croppedCGImage,
                            scale: image.scale,
                            orientation: image.imageOrientation
                        )
                    }
                }
            }
        }

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1
        rendererFormat.preferredRange = .standard
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        let scaledImage = renderer.image { _ in
            imageForResizing.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return scaledImage.cgImage
    }
}
#endif
