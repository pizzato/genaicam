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

/// Predefined style prompts applied to Stable Diffusion generations.
enum StableDiffusionStyle: String, CaseIterable, Identifiable {
    case photoRealistic
    case cinematic
    case digitalPainting
    case watercolor
    case pixelArt
    case comicBook
    case fantasyIllustration
    case lowPoly3D
    case neonNoir
    case claymation

    var id: String { rawValue }

    /// User facing label.
    var title: String {
        switch self {
        case .photoRealistic:
            return "Photo Realistic"
        case .cinematic:
            return "Cinematic Lighting"
        case .digitalPainting:
            return "Digital Painting"
        case .watercolor:
            return "Watercolor"
        case .pixelArt:
            return "Pixel Art"
        case .comicBook:
            return "Comic Book"
        case .fantasyIllustration:
            return "Fantasy Illustration"
        case .lowPoly3D:
            return "Low Poly 3D"
        case .neonNoir:
            return "Neon Noir"
        case .claymation:
            return "Claymation"
        }
    }

    /// Prompt fragment inserted at the start of the Stable Diffusion prompt.
    var prompt: String {
        switch self {
        case .photoRealistic:
            return "photo realistic, ultra detailed, natural lighting"
        case .cinematic:
            return "cinematic lighting, dramatic composition, 35mm film still"
        case .digitalPainting:
            return "digital painting, painterly brushstrokes, rich color"
        case .watercolor:
            return "watercolor painting, soft gradients, fluid pigments"
        case .pixelArt:
            return "pixel art, 8-bit game, sharp pixels"
        case .comicBook:
            return "comic book illustration, bold ink outlines, halftone shading"
        case .fantasyIllustration:
            return "fantasy concept art, epic scale, intricate detail"
        case .lowPoly3D:
            return "low poly 3d render, stylized geometry, flat shading"
        case .neonNoir:
            return "neon noir, moody shadows, vibrant neon glow"
        case .claymation:
            return "claymation stop motion, handcrafted clay texture"
        }
    }

    /// Short explanation displayed in the settings screen.
    var description: String {
        switch self {
        case .photoRealistic:
            return "Produces detailed images resembling real photography."
        case .cinematic:
            return "Creates dramatic scenes with film-inspired lighting."
        case .digitalPainting:
            return "Looks like a vivid digital illustration."
        case .watercolor:
            return "Soft, fluid strokes similar to watercolor artwork."
        case .pixelArt:
            return "Retro 8-bit video game aesthetic."
        case .comicBook:
            return "Bold inked panels styled after comic books."
        case .fantasyIllustration:
            return "Epic fantasy concept illustration."
        case .lowPoly3D:
            return "Stylized 3D render with low polygon shapes."
        case .neonNoir:
            return "High contrast scenes with neon highlights."
        case .claymation:
            return "Playful stop-motion clay characters."
        }
    }

    /// Styles exposed directly in the recreate menu for quick access.
    static var quickAccessStyles: [StableDiffusionStyle] {
        [.photoRealistic, .watercolor, .pixelArt, .claymation]
    }
}

extension StableDiffusionStyle {
    /// Attempts to map a legacy free-form prompt suffix to one of the predefined styles.
    /// Returns `nil` if no reasonable mapping exists.
    init?(legacyPromptSuffix: String) {
        let normalized = legacyPromptSuffix
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized.isEmpty {
            self = .claymation
            return
        }

        switch normalized {
        case "photo, high quality, 8k",
             "photo realistic",
             "photorealistic":
            self = .photoRealistic
        case "pixel art":
            self = .pixelArt
        default:
            return nil
        }
    }
}
