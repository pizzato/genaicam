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

/// Preset inference step options for Stable Diffusion generation.
enum StableDiffusionStepPreset: Int, CaseIterable, Identifiable {
    case fast = 15
    case balanced = 25
    case detailed = 35

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .fast:
            return "Fast (15 steps)"
        case .balanced:
            return "Balanced (25 steps)"
        case .detailed:
            return "Detailed (35 steps)"
        }
    }
}

/// Preset guidance scale options for Stable Diffusion generation.
enum StableDiffusionGuidancePreset: Double, CaseIterable, Identifiable {
    case subtle = 5.5
    case standard = 7.5
    case vibrant = 9.5

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .subtle:
            return "Subtle (5.5)"
        case .standard:
            return "Standard (7.5)"
        case .vibrant:
            return "Vibrant (9.5)"
        }
    }
}
