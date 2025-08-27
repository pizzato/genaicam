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
    @State private var model = FastVLMModel()

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
                                generatedImage = nil
#endif
#if os(iOS) && canImport(ImagePlayground)
                                if #available(iOS 18.0, *), let capturedImage {
                                    Task {
                                        generatedImage = await imageGenerator.generate(from: capturedImage, style: playgroundStyle)
                                        _ = await shortTask.value
                                        await generateLongDescription(frame)
                                    }
                                } else {
                                    Task {
                                        _ = await shortTask.value
                                        await generateLongDescription(frame)
                                    }
                                }
#else
                                Task {
                                    _ = await shortTask.value
                                    await generateLongDescription(frame)
                                }
#endif
                                showPreview = true
                                showDescription = true
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
                            shortDescription: shortDescription,
                            longDescription: longDescription,
                            onRetake: {
                                showPreview = false
                                model.output = ""
                                model.cancel()
                            },
                            onRecreate: { style in
                                recreateImage(style: style)
        }
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

    func recreateImage(style: PlaygroundStyle? = nil) {
#if os(iOS) && canImport(ImagePlayground)
        if #available(iOS 18.0, *), let capturedImage {
            let chosenStyle = style ?? playgroundStyle
            Task {
                generatedImage = nil
                generatedImage = await imageGenerator.generate(
                    from: capturedImage,
                    style: chosenStyle
                )
            }
        }
#endif
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
