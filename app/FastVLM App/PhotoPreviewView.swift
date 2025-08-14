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
    @Binding var prompt: String
    @Binding var style: PlaygroundStyle
    var onRetake: () -> Void

    @State private var showingDescription = false
    @State private var showShare = false
    @State private var showSettings = false
    @State private var selection: ImageSelection = .original
    private let buttonSize: CGFloat = 80

    enum ImageSelection: String, CaseIterable, Identifiable {
        case original
        case generated
        var id: String { rawValue }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: selection == .original ? image : (generatedImage ?? image))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                VStack {
                    HStack(spacing: 20) {
                        if generatedImage != nil {
                            Button {
                                selection = selection == .original ? .generated : .original
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: selection == .original ? "photo" : "sparkles")
                                        .font(.title)
                                    Text(selection == .original ? "Generated" : "Original")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(width: buttonSize, height: buttonSize)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            }
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "photo")
                                    .font(.title)
                                Text("Original")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }

                        Button {
                            showSettings = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "gearshape.fill")
                                    .font(.title)
                                Text("Settings")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }

        
                        Button {
                            showingDescription.toggle()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "text.bubble.fill")
                                    .font(.title)
                                Text("Info")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 60)

                    Spacer()

                    HStack(spacing: 20) {
                        Button {
                            onRetake()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "camera")
                                    .font(.title)
                                Text("New Photo")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }

                        Button {
                            savePhoto()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.title)
                                Text("Save")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }

                        Button {
                            showShare = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title)
                                Text("Share")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(width: buttonSize, height: buttonSize)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .sheet(isPresented: $showShare) {
                            ShareSheet(activityItems: [image, generatedImage].compactMap { $0 })
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 50)
                }

                if showingDescription {
                    ZStack {
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showingDescription = false
                            }

                        VStack(spacing: 20) {
                            Text("Description")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            ScrollView {
                                Text(description)
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                            .frame(maxHeight: 300)

                            Button("Close") {
                                showingDescription = false
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(25)
                        }
                        .padding(30)
                        .background(Color.black.opacity(0.9))
                        .cornerRadius(20)
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: generatedImage) { newValue in
            if newValue != nil {
                selection = .generated
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(prompt: $prompt, style: $style)
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
