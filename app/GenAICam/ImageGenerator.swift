//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
import CoreML
#if canImport(StableDiffusion) && os(iOS)
import StableDiffusion
#endif
#if os(iOS)
import UIKit
#if canImport(ImagePlayground)
import ImagePlayground
#endif
#endif

/// Style options for Image Playground generation.
enum PlaygroundStyle: String, CaseIterable, Identifiable {
    case sketch
    case illustration
    case animation
    var id: String { rawValue }
}

/// Available image generation engines.
enum ImageGenerationMode: String, CaseIterable, Identifiable {
    case playground
    case stableDiffusion
    var id: String { rawValue }
}

#if canImport(ImagePlayground)
/// Wrapper around Image Playground to generate images in the background.
@MainActor
@available(iOS 18.0, *)
class PlaygroundImageGenerator {
    private var creator: ImageCreator?

    init() {}

    /// Generate a new image based on the provided one using Image Playground.
    /// - Parameters:
    ///   - image: Source image.
    ///   - style: Desired generation style.
    /// - Returns: Generated image or nil if generation fails.
    func generate(from image: UIImage, style: PlaygroundStyle) async -> UIImage? {
        do {
            if creator == nil {
                creator = try await ImageCreator()
            }
            guard let creator, let cgImage = image.cgImage else { return nil }
            let concepts: [ImagePlaygroundConcept] = [.image(cgImage)]

            // Map our simple `PlaygroundStyle` to the corresponding
            // `ImagePlaygroundStyle`. The ImagePlayground API doesn't expose
            // a `RawRepresentable` initializer, so we translate explicitly.
            let playgroundStyle: ImagePlaygroundStyle
            switch style {
            case .sketch:
                playgroundStyle = .sketch
            case .illustration:
                playgroundStyle = .illustration
            case .animation:
                playgroundStyle = .animation
            }

            let images = creator.images(for: concepts, style: playgroundStyle, limit: 1)
            for try await result in images {
                return UIImage(cgImage: result.cgImage)
            }
        } catch {
            return nil
        }
        return nil
    }
}
#else
@MainActor
@available(iOS 18.0, *)
class PlaygroundImageGenerator {
    init() {}

    /// Stub generator when ImagePlayground is unavailable.
    /// - Parameters:
    ///   - image: Source image.
    ///   - style: Desired generation style.
    /// - Returns: Always nil.
      func generate(from image: UIImage, style: PlaygroundStyle) async -> UIImage? { nil }
}
#endif

#if canImport(StableDiffusion) && os(iOS)
/// Wrapper around the Core ML Stable Diffusion pipeline.
@available(iOS 16.2, macOS 13.1, *)
class StableDiffusionImageGenerator {
    private var pipeline: StableDiffusionPipeline?

    init() {}

    /// Generate an image from a prompt using the Stable Diffusion pipeline.
    /// - Parameters:
    ///   - prompt: The text prompt describing the desired image.
    ///   - progressHandler: Closure called on each step with the current step and total steps.
    /// - Returns: Generated image or `nil` if generation fails.
    func generate(prompt: String,
                  progressHandler: @escaping @MainActor (Int, Int) -> Void) async -> UIImage? {
        print("[StableDiffusion] Starting generation for prompt: \(prompt)")
        do {
            if pipeline == nil {
                let resources = StableDiffusionModel.modelDirectory
                let config = MLModelConfiguration()
                config.computeUnits = .all
                pipeline = try StableDiffusionPipeline(resourcesAt: resources, configuration: config)
                print("[StableDiffusion] Loaded pipeline from \(resources.path)")
            }
            guard let pipeline else { return nil }
            var sdConfig = StableDiffusionPipeline.Configuration(prompt: prompt)
            sdConfig.stepCount = 20
            let images = try pipeline.generateImages(configuration: sdConfig) { progress in
                let step = progress.step + 1
                let total = progress.stepCount
                print("[StableDiffusion] Generation progress: step \(step) of \(total)")
                DispatchQueue.main.async {
                    progressHandler(step, total)
                }
                return true
            }
            if let cgImage = images.compactMap({ $0 }).first {
                print("[StableDiffusion] Generation complete")
                return UIImage(cgImage: cgImage)
            }
        } catch {
            print("[StableDiffusion] Generation failed: \(error.localizedDescription)")
            return nil
        }
        return nil
    }
}
#else
class StableDiffusionImageGenerator {
    init() {}
    func generate(prompt: String,
                  progressHandler: @escaping @MainActor (Int, Int) -> Void) async -> UIImage? { nil }
}
#endif

