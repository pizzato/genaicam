//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
#if os(iOS)
import UIKit
#if canImport(ImagePlayground)
import ImagePlayground
#endif
#if canImport(StableDiffusion)
import StableDiffusion
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
#endif

#if canImport(StableDiffusion)
/// Wrapper around the Core ML Stable Diffusion pipeline.
@MainActor
class StableDiffusionImageGenerator {
    private var pipeline: StableDiffusionPipeline?

    init() {}

    /// Generate an image from a prompt using the Stable Diffusion pipeline.
    /// - Parameter prompt: The text prompt describing the desired image.
    /// - Returns: Generated image or `nil` if generation fails.
    func generate(prompt: String) async -> UIImage? {
        do {
            if pipeline == nil {
                let resources = StableDiffusionModel.modelDirectory
                pipeline = try StableDiffusionPipeline(resourcesAt: resources, configuration: MLModelConfiguration())
            }
            guard let pipeline else { return nil }
            let images = try await pipeline.generate(prompt: prompt, stepCount: 20)
            if let cgImage = images.first {
                return UIImage(cgImage: cgImage)
            }
        } catch {
            return nil
        }
        return nil
    }
}
#else
@MainActor
class StableDiffusionImageGenerator {
    init() {}
    func generate(prompt: String) async -> UIImage? { nil }
}
#endif

