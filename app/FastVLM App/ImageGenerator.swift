//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
#if os(iOS)
import UIKit
#if canImport(ImagePlayground)
import ImagePlayground

/// Wrapper around Image Playground to generate images in the background.
@MainActor
@available(iOS 18.0, *)
class PlaygroundImageGenerator {
    private var creator: ImageCreator?

    init() {}

    /// Generate a new image based on the provided one using Image Playground.
    /// - Parameter image: Source image.
    /// - Returns: Generated image or nil if generation fails.
    func generate(from image: UIImage) async -> UIImage? {
        do {
            if creator == nil {
                creator = try await ImageCreator()
            }
            guard let creator, let cgImage = image.cgImage else { return nil }
            let concepts: [ImagePlaygroundConcept] = [.image(cgImage)]
            let images = creator.images(for: concepts, style: .sketch, limit: 1)
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
    /// - Parameter image: Source image.
    /// - Returns: Always nil.
    func generate(from image: UIImage) async -> UIImage? { nil }
}
#endif
#endif
