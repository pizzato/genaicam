//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
#if os(iOS)
import UIKit
#if canImport(ImagePlayground)
@available(iOS 18.0, *)
import ImagePlayground

/// Wrapper around Image Playground to generate images in the background.
@MainActor
@available(iOS 18.0, *)
class PlaygroundImageGenerator {
    private let session: PlaygroundSession?

    init() {
        session = try? PlaygroundSession()
    }

    /// Generate a new image based on the provided one using Image Playground.
    /// - Parameter image: Source image.
    /// - Returns: Generated image or nil if generation fails.
    func generate(from image: UIImage) async -> UIImage? {
        guard let session else { return nil }
        do {
            let request = PlaygroundImageRequest(referenceImage: image)
            let result = try await session.image(from: request)
            return result
        } catch {
            return nil
        }
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
