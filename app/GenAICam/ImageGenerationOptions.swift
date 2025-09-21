//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation

/// Available providers for image generation.
enum ImageGeneratorProvider: String, CaseIterable, Identifiable {
    case stableDiffusion
    case imagePlayground

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stableDiffusion:
            return "Stable Diffusion"
        case .imagePlayground:
            return "Image Playground"
        }
    }

    var description: String {
        switch self {
        case .stableDiffusion:
            return "Generates images using the downloaded Stable Diffusion 2.1 model."
        case .imagePlayground:
            return "Uses Apple Intelligence Image Playground when available."
        }
    }
}

/// Determines how Stable Diffusion should initialize the latent noise.
enum StableDiffusionStartMode: String, CaseIterable, Identifiable {
    case noise
    case photo

    var id: String { rawValue }

    /// Short label used in pickers and menus.
    var label: String {
        switch self {
        case .noise:
            return "Noise"
        case .photo:
            return "Photo"
        }
    }

    /// User-facing description of the mode.
    var description: String {
        switch self {
        case .noise:
            return "Start from random noise for a completely new image."
        case .photo:
            return "Use the captured photo as the starting point for image-to-image generation."
        }
    }
}
