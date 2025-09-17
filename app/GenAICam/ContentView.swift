//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import AVFoundation
import MLXLMCommon
import SwiftUI
import Video
import CoreImage
import Foundation
#if os(iOS)
import UIKit
#endif
#if os(iOS) && canImport(ImagePlayground)
import ImagePlayground
#endif

// support swift 6
extension CVImageBuffer: @unchecked @retroactive Sendable {}
extension CMSampleBuffer: @unchecked @retroactive Sendable {}

// delay between frames -- controls the frame rate of the updates
let FRAME_DELAY = Duration.milliseconds(1)

enum DescriptionMode: String, CaseIterable, Identifiable {
    case short
    case long
    var id: String { rawValue }
}

//let shortPromptSuffix = "Output is very brief for a less capable image generation task, use maximum of 10 words."
//let longPromptSuffix = "Output is prompt to reconstruct the image. If describing a person, be specific on gender, age estimate and any distinguishing features, such as ethnicity or hair color, eye colour, etc."

let shortPromptSuffix = "Output is very brief use maximum of 10 words."
let longPromptSuffix = "Long and detailed description please."

struct ContentView: View {
    @State private var camera = CameraController()
    @StateObject private var model = FastVLMModel()

    /// stream of frames -> VideoFrameView, see distributeVideoFrames
    @State private var framesToDisplay: AsyncStream<CVImageBuffer>?
    @State private var latestFrame: CVImageBuffer?

    private let prompt = "Describe the image in English."
    @State private var descriptionMode: DescriptionMode = .short
    var promptSuffix: String {
        descriptionMode == .short ? shortPromptSuffix : longPromptSuffix
    }
    @State private var shortDescription: String = ""
    @State private var longDescription: String = ""
    @State private var showSettings: Bool = false

    @State private var isRealTime: Bool = false
    @State private var showDescription: Bool = false
    @State private var capturedImage: UIImage?
    @State private var showPreview: Bool = false
#if os(iOS)
    @State private var generatedImage: UIImage?
    @State private var generationStatus: String?
    @State private var generationTask: Task<Void, Never>?
    @AppStorage("imageGeneratorProvider") private var imageGeneratorProvider: ImageGeneratorProvider = .stableDiffusion
    @AppStorage("stableDiffusionStepCount") private var stableDiffusionStepCount: Int = StableDiffusionStepPreset.balanced.rawValue
    @AppStorage("stableDiffusionGuidance") private var stableDiffusionGuidance: Double = StableDiffusionGuidancePreset.standard.rawValue
    @StateObject private var stableDiffusionGenerator = StableDiffusionGenerator()
#endif
#if os(iOS) && canImport(ImagePlayground)
    @available(iOS 18.0, *)
    @State private var imageGenerator = PlaygroundImageGenerator()
    @available(iOS 18.0, *)
    @AppStorage("playgroundStyle") private var playgroundStyle: PlaygroundStyle = .sketch
#endif
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showWelcome: Bool = false
    @State private var previousOutput: String = ""
    @State private var diffedOutput: AttributedString = ""

    var body: some View {
        ZStack {
            if let framesToDisplay {
                VideoFrameView(
                    frames: framesToDisplay,
                    cameraType: .continuous,
                    action: nil
                )
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack {
                Spacer()

                VStack(spacing: 16) {
                    if showDescription && !model.output.isEmpty {
                        if isRealTime {
                            Text(diffedOutput)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                        } else {
                            Text(model.output)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                        }
                    }

                    HStack {
                        Button {
                            camera.backCamera.toggle()
                        } label: {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                                        .foregroundStyle(.white)
                                )
                        }

                        Spacer()

                        Button {
                            if let frame = latestFrame {
                                if isRealTime {
                                    isRealTime = false
                                    showDescription = false
                                    model.cancel()
                                }
                                shortDescription = ""
                                let shortTask = Task { await generateShortDescription(frame) }
                                capturedImage = makeUIImage(from: frame)
#if os(iOS)
                                cancelImageGeneration()
                                generatedImage = nil
                                generationStatus = nil
#endif
                                showPreview = true
                                showDescription = true
                                Task {
                                    _ = await shortTask.value
                                    await MainActor.run {
                                        startImageGeneration()
                                    }
                                    await generateLongDescription(frame)
                                }
                            }
                        } label: {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black.opacity(0.2), lineWidth: 2)
                                )
                        }

                        Spacer()

                        Button {
                            showSettings = true
                        } label: {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "gearshape")
                                        .foregroundStyle(.white)
                                )
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)
            }
        }
        .task {
            await distributeVideoFrames()
        }
        .onAppear {
            if !hasSeenWelcome {
                showWelcome = true
            }
        }
        #if os(iOS)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .fullScreenCover(isPresented: $showPreview) {
            if let capturedImage {
                        PhotoPreviewView(
                            image: capturedImage,
                            generatedImage: $generatedImage,
                            description: $shortDescription,
                            generationStatus: $generationStatus,
                            shortDescription: shortDescription,
                            longDescription: longDescription,
                            onRetake: {
                                showPreview = false
                                model.output = ""
                                model.cancel()
                                cancelImageGeneration()
                            },
                            onRecreate: {
                                startImageGeneration()
                            },
                            generationOptions: generationContextMenuItems()
                        )
            }
        }
#endif
        .sheet(isPresented: $showWelcome, onDismiss: { hasSeenWelcome = true }) {
            WelcomeView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                style: $playgroundStyle,
                provider: $imageGeneratorProvider,
                stableDiffusionStepCount: $stableDiffusionStepCount,
                stableDiffusionGuidance: $stableDiffusionGuidance,
                mode: $descriptionMode,
                isRealTime: $isRealTime,
                showDescription: $showDescription
            )
        }
        .onChange(of: isRealTime) { _, newValue in
            showDescription = newValue
            model.cancel()
            if newValue {
                previousOutput = ""
                diffedOutput = AttributedString("")
            }
        }
        .onChange(of: model.output) { _, newValue in
            guard isRealTime else {
                previousOutput = newValue
                diffedOutput = AttributedString(newValue)
                diffedOutput.foregroundColor = .white
                return
            }

            let prefix = newValue.commonPrefix(with: previousOutput)
            let suffix = String(newValue.dropFirst(prefix.count))

            var attr = AttributedString(prefix)
            attr.foregroundColor = .white

            var suffixAttr = AttributedString(suffix)
            suffixAttr.foregroundColor = .green

            diffedOutput = attr + suffixAttr
            previousOutput = newValue
        }
    }

    func analyzeVideoFrames(_ frames: AsyncStream<CVImageBuffer>) async {
        for await frame in frames {
            let userInput = UserInput(
                prompt: .text("\(prompt) \(promptSuffix)"),
                images: [.ciImage(CIImage(cvPixelBuffer: frame))]
            )

            let t = await model.generate(userInput, stream: false)
            _ = await t.result

            do {
                try await Task.sleep(for: FRAME_DELAY)
            } catch { return }
        }
    }

    func distributeVideoFrames() async {
        let frames = AsyncStream<CMSampleBuffer>(bufferingPolicy: .bufferingNewest(1)) {
            camera.attach(continuation: $0)
        }

        // Ensure the camera capture session is running before we begin
        // distributing frames so the preview is available immediately.
        camera.start()

        let (framesToDisplay, displayCont) = AsyncStream.makeStream(
            of: CVImageBuffer.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        self.framesToDisplay = framesToDisplay

        let (framesToAnalyze, analyzeCont) = AsyncStream.makeStream(
            of: CVImageBuffer.self,
            bufferingPolicy: .bufferingNewest(1)
        )

        async let analyze: () = analyzeVideoFrames(framesToAnalyze)

        for await sampleBuffer in frames {
            if let frame = sampleBuffer.imageBuffer {
                displayCont.yield(frame)
                await MainActor.run { latestFrame = frame }
                let realtime = await MainActor.run { self.isRealTime }
                if realtime {
                    analyzeCont.yield(frame)
                }
            }
        }

        await MainActor.run {
            self.framesToDisplay = nil
            self.camera.detatch()
            self.camera.stop()
        }

        displayCont.finish()
        analyzeCont.finish()
        await analyze
    }

    func generateShortDescription(_ frame: CVImageBuffer) async {
        await MainActor.run {
            model.output = ""
            shortDescription = ""
            longDescription = ""
        }

        let image = CIImage(cvPixelBuffer: frame)

        let shortInput = UserInput(
            prompt: .text("\(prompt) \(shortPromptSuffix)"),
            images: [.ciImage(image)]
        )
        let shortTask = await model.generate(shortInput)
        _ = await shortTask.result
        let shortDesc = model.output

        await MainActor.run {
            self.shortDescription = shortDesc
            self.model.output = shortDesc
        }
    }

    func generateLongDescription(_ frame: CVImageBuffer) async {
        let image = CIImage(cvPixelBuffer: frame)

        let longInput = UserInput(
            prompt: .text("\(prompt) \(longPromptSuffix)"),
            images: [.ciImage(image)]
        )
        let longTask = await model.generate(longInput)
        _ = await longTask.result
        let longDesc = model.output

        await MainActor.run {
            self.longDescription = longDesc
            self.model.output = self.shortDescription
        }
    }

    func cancelImageGeneration() {
#if os(iOS)
        generationTask?.cancel()
        generationTask = nil
        generationStatus = nil
        if #available(iOS 17.0, *) {
            stableDiffusionGenerator.cancelGeneration()
        }
#endif
    }

    func startImageGeneration(style: PlaygroundStyle? = nil) {
#if os(iOS)
        guard let capturedImage else { return }

        let provider = imageGeneratorProvider
        let chosenStyle = style ?? playgroundStyle
        generationTask?.cancel()
        if #available(iOS 17.0, *) {
            stableDiffusionGenerator.cancelGeneration()
        }
        generationStatus = "Preparing..."
        generatedImage = nil

        generationTask = Task { [weak self] in
            guard let self else { return }
            defer { await MainActor.run { self.generationTask = nil } }

            switch provider {
            case .imagePlayground:
#if canImport(ImagePlayground)
                if #available(iOS 18.0, *) {
                    let result = await imageGenerator.generate(
                        from: capturedImage,
                        style: chosenStyle
                    )
                    await MainActor.run {
                        self.generatedImage = result
                        self.generationStatus = result == nil ? "Generation failed" : nil
                    }
                } else {
                    await MainActor.run {
                        self.generationStatus = "Image Playground requires iOS 18"
                    }
                }
#else
                await MainActor.run {
                    self.generationStatus = "Image Playground unavailable"
                }
#endif

            case .stableDiffusion:
                guard #available(iOS 17.0, *) else {
                    await MainActor.run {
                        self.generationStatus = "Stable Diffusion requires iOS 17"
                    }
                    return
                }

                let prompt = await MainActor.run { () -> String in
                    let trimmedLong = self.longDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedLong.isEmpty { return trimmedLong }
                    let trimmedShort = self.shortDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmedShort.isEmpty ? "A high quality photograph" : trimmedShort
                }

                do {
                    let image = try await stableDiffusionGenerator.generate(
                        prompt: prompt,
                        stepCount: max(stableDiffusionStepPreset(from: self.stableDiffusionStepCount), 1),
                        guidanceScale: Float(self.stableDiffusionGuidance),
                        progress: { step, total in
                            Task { @MainActor in
                                let cappedTotal = max(total, 1)
                                let displayStep = min(max(step, 1), cappedTotal)
                                self.generationStatus = "Step \(displayStep) of \(cappedTotal)"
                            }
                        }
                    )
                    await MainActor.run {
                        self.generatedImage = image
                        self.generationStatus = image == nil ? "Generation canceled" : nil
                    }
                } catch StableDiffusionGenerator.GenerationError.modelMissing {
                    await MainActor.run {
                        self.generationStatus = "Download Stable Diffusion from the setup screen"
                    }
                } catch {
                    await MainActor.run {
                        self.generationStatus = "Generation failed: \(error.localizedDescription)"
                    }
                }
            }
        }
#endif
    }

    func generationContextMenuItems() -> [GenerationOption] {
#if os(iOS)
        switch imageGeneratorProvider {
        case .imagePlayground:
#if canImport(ImagePlayground)
            return PlaygroundStyle.allCases.map { style in
                GenerationOption(
                    id: "style-\(style.rawValue)",
                    title: style.rawValue.capitalized,
                    isSelected: style == playgroundStyle
                ) {
                    playgroundStyle = style
                    startImageGeneration(style: style)
                }
            }
#else
            return []
#endif
        case .stableDiffusion:
            var items: [GenerationOption] = []
            for preset in StableDiffusionStepPreset.allCases {
                items.append(
                    GenerationOption(
                        id: "steps-\(preset.rawValue)",
                        title: preset.label,
                        isSelected: preset.rawValue == stableDiffusionStepCount
                    ) {
                        stableDiffusionStepCount = preset.rawValue
                        startImageGeneration()
                    }
                )
            }
            for preset in StableDiffusionGuidancePreset.allCases {
                items.append(
                    GenerationOption(
                        id: "guidance-\(preset.rawValue)",
                        title: preset.label,
                        isSelected: preset.rawValue == stableDiffusionGuidance
                    ) {
                        stableDiffusionGuidance = preset.rawValue
                        startImageGeneration()
                    }
                )
            }
            return items
        }
#else
        return []
#endif
    }

    private func stableDiffusionStepPreset(from value: Int) -> Int {
        StableDiffusionStepPreset(rawValue: value)?.rawValue ?? StableDiffusionStepPreset.balanced.rawValue
    }

    func makeUIImage(from buffer: CVImageBuffer) -> UIImage? {
        #if os(iOS)
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        #endif
        return nil
    }
}

#Preview {
    ContentView()
}
