//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
#if os(iOS)
import UIKit
import ImagePlayground

/// Wrapper around Image Playground to generate images in the background.
@MainActor
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
#endif
