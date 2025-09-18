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
    @Binding var generationStatus: String?
    let shortDescription: String
    let longDescription: String
    var onRetake: () -> Void
    var onRecreate: () -> Void
    var generationOptions: [GenerationOption]

    @State private var showShare = false
    @State private var showMore = false
    @State private var selection: ImageSelection = .original
    private let buttonSize: CGFloat = 80

    enum ImageSelection: String, CaseIterable, Identifiable {
        case original
        case generated
        var id: String { rawValue }
    }

    var body: some View {
        GeometryReader { geometry in
            let showingGenerated = selection == .generated && generatedImage != nil
            let displayedImage = showingGenerated ? (generatedImage ?? image) : image

            ZStack {
                Color.black
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()

                Image(uiImage: displayedImage)
                    .resizable()
                    .aspectRatio(contentMode: showingGenerated ? .fit : .fill)
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
                                Text("Generated")
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
                            onRecreate()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title)
                                Text("Recreate")
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
                        .contextMenu {
                            if generationOptions.isEmpty {
                                Button("Recreate") { onRecreate() }
                            } else {
                                ForEach(generationOptions) { option in
                                    Button {
                                        option.action()
                                    } label: {
                                        HStack {
                                            Text(option.title)
                                            if option.isSelected {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        }

        
                        Button {
                            showMore = true
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title)
                                Text("More")
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
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 30)
                    .padding(.top, 60)

                    Spacer()

                    if generatedImage == nil {
                        VStack(spacing: 16) {
                            if let status = generationStatus {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                Text(status)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                if !description.isEmpty {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                }
                            } else if !description.isEmpty {
                                Text(description)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            } else {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                                Text("Preparing image...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(24)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(18)
                        .padding(.horizontal, 32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }

                    
                    
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
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 50)
                }

            }
        }
        .ignoresSafeArea()
        // Use the new two-parameter `onChange` available in iOS 17 while
        // falling back to the legacy single-parameter version on older
        // systems to avoid deprecation warnings during compilation.
        .modifier(
            OnChangeModifier(generatedImage: $generatedImage) { newValue in
                if newValue != nil {
                    selection = .generated
                }
            }
        )
        .sheet(isPresented: $showMore) {
            MoreView(
                shortDescription: shortDescription,
                longDescription: longDescription
            )
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

struct GenerationOption: Identifiable {
    let id: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
}

/// View modifier that applies the appropriate `onChange` variant depending on
/// the iOS version. This keeps the main view declarative while avoiding the
/// deprecation warning on iOS 17 and above.
private struct OnChangeModifier: ViewModifier {
    @Binding var generatedImage: UIImage?
    let action: (UIImage?) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.onChange(of: generatedImage, initial: false) { _, newValue in
                action(newValue)
            }
        } else {
            content.onChange(of: generatedImage) { newValue in
                action(newValue)
            }
        }
    }
}
#endif
