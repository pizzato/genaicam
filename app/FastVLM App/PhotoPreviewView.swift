//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI
import Photos
#if os(iOS)
import UIKit

struct PhotoPreviewView: View {
    let image: UIImage
    @Binding var generatedImage: UIImage?
    @Binding var description: String
    let prompt: String
    var onRetake: () -> Void

    @State private var showPrompt = false
    @State private var showShare = false
    @State private var selection: ImageSelection = .original

    enum ImageSelection: String, CaseIterable, Identifiable {
        case original
        case generated
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Image(uiImage: selection == .original ? image : (generatedImage ?? image))
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()

            VStack {
                HStack {
                    if generatedImage != nil {
                        Picker("", selection: $selection) {
                            Text("Original").tag(ImageSelection.original)
                            Text("Generated").tag(ImageSelection.generated)
                        }
                        .pickerStyle(.segmented)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    } else {
                        Label("Original", systemImage: "sparkles")
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                    Spacer()
                    Button {
                        showPrompt = true
                    } label: {
                        Label("Info", systemImage: "info.circle")
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .foregroundStyle(.white)

                Spacer()

                if !description.isEmpty {
                    Text(description)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding()
                }

                HStack(spacing: 40) {
                    Button {
                        onRetake()
                    } label: {
                        VStack {
                            Image(systemName: "camera")
                            Text("New Photo")
                                .font(.caption)
                        }
                    }

                    Button {
                        savePhoto()
                    } label: {
                        VStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save")
                                .font(.caption)
                        }
                    }

                    Button {
                        showShare = true
                    } label: {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                                .font(.caption)
                        }
                    }
                    .sheet(isPresented: $showShare) {
                        ShareSheet(activityItems: [image, generatedImage].compactMap { $0 })
                    }
                }
                .padding(.bottom, 40)
                .foregroundStyle(.white)
            }
        }
        .alert("Prompt", isPresented: $showPrompt) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(prompt)
        }
    }

    func savePhoto() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                if let generatedImage {
                    UIImageWriteToSavedPhotosAlbum(generatedImage, nil, nil, nil)
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
