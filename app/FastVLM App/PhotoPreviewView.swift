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
    private let buttonSize: CGFloat = 70

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
                        Button {
                            selection = selection == .original ? .generated : .original
                        } label: {
                            Text(selection == .generated ? "Original" : "Generated")
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color.black)
                                .cornerRadius(12)
                        }
                    } else {
                        Text("Original")
                            .frame(width: buttonSize, height: buttonSize)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    Spacer()
                    Button {
                        showPrompt = true
                    } label: {
                        VStack {
                            Image(systemName: "info.circle")
                            Text("Info")
                                .font(.caption)
                        }
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.black)
                        .cornerRadius(12)
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

                HStack(spacing: 20) {
                    Button {
                        onRetake()
                    } label: {
                        VStack {
                            Image(systemName: "camera")
                            Text("New Photo")
                                .font(.caption)
                        }
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.black)
                        .cornerRadius(12)
                    }

                    Button {
                        savePhoto()
                    } label: {
                        VStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save")
                                .font(.caption)
                        }
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.black)
                        .cornerRadius(12)
                    }

                    Button {
                        showShare = true
                    } label: {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                                .font(.caption)
                        }
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Color.black)
                        .cornerRadius(12)
                    }
                    .sheet(isPresented: $showShare) {
                        ShareSheet(activityItems: [image, generatedImage].compactMap { $0 })
                    }
                }
                .padding(.bottom, 40)
                .foregroundStyle(.white)
            }
        }
        .onChange(of: generatedImage) { newValue in
            if newValue != nil {
                selection = .generated
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
