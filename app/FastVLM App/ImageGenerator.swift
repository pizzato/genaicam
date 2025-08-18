//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
#if os(iOS)
import UIKit
import Vision
#if canImport(ImagePlayground)
import ImagePlayground
#endif

/// Style options for Image Playground generation.
enum PlaygroundStyle: String, CaseIterable, Identifiable {
    case sketch
    case illustration
    case animation
    var id: String { rawValue }
}

#if canImport(ImagePlayground)
/// Wrapper around Image Playground to generate images in the background.
@MainActor
@available(iOS 18.0, *)
class PlaygroundImageGenerator {
    private var creator: ImageCreator?

    init() {}

    /// Generate concepts for Image Playground. When a person is detected in the
    /// input image, the person's region is cropped and used as individual
    /// concepts. Otherwise the full image is used as a single concept.
    /// - Parameter cgImage: Source image.
    /// - Returns: Array of concepts to drive image generation.
    private func personConcepts(from cgImage: CGImage) -> [ImagePlaygroundConcept] {
        let request = VNDetectHumanRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            if let observations = request.results as? [VNHumanObservation] {
                let concepts: [ImagePlaygroundConcept] = observations.compactMap { obs in
                    let rect = VNImageRectForNormalizedRect(
                        obs.boundingBox,
                        cgImage.width,
                        cgImage.height)
                    guard let cropped = cgImage.cropping(to: rect) else { return nil }
                    return .image(cropped)
                }
                if !concepts.isEmpty {
                    return concepts
                }
            }
        } catch {
            // If detection fails, fall back to using the whole image.
        }
        return [.image(cgImage)]
    }

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
            let concepts = personConcepts(from: cgImage)

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
