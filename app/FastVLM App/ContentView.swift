//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import AVFoundation
import MLXLMCommon
import SwiftUI
import Video
import CoreImage
#if os(iOS)
import UIKit
#endif

// support swift 6
extension CVImageBuffer: @unchecked @retroactive Sendable {}
extension CMSampleBuffer: @unchecked @retroactive Sendable {}

// delay between frames -- controls the frame rate of the updates
let FRAME_DELAY = Duration.milliseconds(1)

struct ContentView: View {
    @State private var camera = CameraController()
    @State private var model = FastVLMModel()

    /// stream of frames -> VideoFrameView, see distributeVideoFrames
    @State private var framesToDisplay: AsyncStream<CVImageBuffer>?
    @State private var latestFrame: CVImageBuffer?

    @State private var prompt = "Describe the image in English."
    @State private var promptSuffix = "Output should be brief, about 15 words or less."

    @State private var isRealTime: Bool = false
    @State private var showDescription: Bool = false
    @State private var capturedImage: UIImage?
    @State private var showPreview: Bool = false

    var body: some View {
        ZStack {
            if let framesToDisplay {
                VideoFrameView(
                    frames: framesToDisplay,
                    cameraType: .continuous,
                    action: nil
                )
                .ignoresSafeArea()
                #if !os(macOS)
                .overlay(alignment: .topLeading) {
                    CameraControlsView(
                        backCamera: $camera.backCamera,
                        device: $camera.device,
                        devices: $camera.devices
                    )
                    .padding()
                }
                #endif
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        isRealTime.toggle()
                        showDescription = isRealTime
                        model.cancel()
                    } label: {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 24))
                            .foregroundStyle(isRealTime ? .green : .white)
                            .padding()
                    }
                }

                Spacer()

                VStack(spacing: 16) {
                    if showDescription {
                        Text(model.output)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }

                    Button {
                        if !isRealTime, let frame = latestFrame {
                            processSingleFrame(frame)
                            capturedImage = makeUIImage(from: frame)
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
                }
                .padding(.bottom, 40)
            }
        }
        .task {
            await distributeVideoFrames()
        }
        #if os(iOS)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        #endif
        .fullScreenCover(isPresented: $showPreview) {
            if let capturedImage {
                PhotoPreviewView(
                    image: capturedImage,
                    description: $model.output,
                    prompt: prompt
                ) {
                    showPreview = false
                    model.output = ""
                }
            }
        }
    }

    func analyzeVideoFrames(_ frames: AsyncStream<CVImageBuffer>) async {
        for await frame in frames {
            let userInput = UserInput(
                prompt: .text("\(prompt) \(promptSuffix)"),
                images: [.ciImage(CIImage(cvPixelBuffer: frame))]
            )

            let t = await model.generate(userInput)
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
        }

        displayCont.finish()
        analyzeCont.finish()
        await analyze
    }

    /// Perform FastVLM inference on a single frame.
    /// - Parameter frame: The frame to analyze.
    func processSingleFrame(_ frame: CVImageBuffer) {
        // Reset Response UI (show spinner)
        Task { @MainActor in
            model.output = ""
        }

        // Construct request to model
        let userInput = UserInput(
            prompt: .text("\(prompt) \(promptSuffix)"),
            images: [.ciImage(CIImage(cvPixelBuffer: frame))]
        )

        // Post request to FastVLM
        Task {
            await model.generate(userInput)
        }
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
