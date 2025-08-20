//
//  WelcomeView.swift
//
//  For licensing see accompanying LICENSE file.
//

import SwiftUI

struct MarkdownText: View {
    let markdown: String
    var baseURL: URL? = nil          // useful for relative links

    var body: some View {
        Text(attributed)
            .tint(.blue)             // link color
            .multilineTextAlignment(.leading)
    }

    private var attributed: AttributedString {
        // iOS 15+
        (try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full    // parse headings, emphasis, links, etc.
            ),
            baseURL: baseURL
        )) ?? AttributedString(markdown)   // fallback: plain text
    }
}

// Minimal bullet row that keeps inline formatting in MarkdownText
private struct BulletRow: View {
    let markdown: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.title3)
                .padding(.top, 2)
            MarkdownText(markdown: markdown)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}


struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "FastVLM"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    let about = """
    ## About This Project

    This app is a **proof of concept** exploring privacy-focused, on-device machine learning.  
    It can describe what it sees and generate pictures from those descriptions — all processed locally on your device.

    The project was developed by **Luiz Pizzato**  
    ([LinkedIn](https://www.linkedin.com/in/pizzato/) • [GitHub](https://github.com/pizzato) • [Medium](https://medium.com/@pizzato))  

    👉 You can also read more about it in this [Medium post](https://medium.com/placeholder-link).

    ### Inspiration
    The idea was inspired by [Lingcam by Masaru Mizuochi](https://lingcam.mizumasa.net/), presented at [CVPR 2025 AI Art](https://thecvf-art.com/project/lingcam/).

    ### How It Was Built
    - Started from Apple’s [FastVLM repository](https://openaccess.thecvf.com/content/CVPR2025/html/Vasu_FastVLM_Efficient_Vision_Encoding_for_Vision_Language_Models_CVPR_2025_paper.html), which introduced efficient vision encoding for vision-language models.  
    - Integrated with [Apple Intelligence Playground](https://developer.apple.com/machine-learning/apple-intelligence-playground/) for image resolution, enabling a fully offline, on-device AI experience.  
    - Initial development was assisted by [OpenAI’s Codex](https://openai.com/codex/).

    ---

    ### Disclaimer
    This project is provided **as is**, without warranty of any kind.  
    Use at your own risk. No guarantees are made regarding accuracy, reliability, or fitness for any purpose.  
    By using this app, you agree that the developer is not liable for any outcomes, damages, or issues arising from its use.

    ---

    This is a free and open-source project — built for learning, creativity, and exploration.

    """

    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    HStack(spacing: 8) {
                        Image("luiz")
                            .resizable()
                            .frame(width: 128, height: 128)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(appName)
                            .font(.largeTitle)
                            .bold()
                    }

                    Text("Version \(appVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()


                    // Each MarkdownText is one paragraph; no headings or line breaks inside.
                    MarkdownText(markdown:
                        "This app is a **proof of concept** exploring privacy-focused, on-device machine learning. It can describe what it sees and generate pictures from those descriptions — all processed locally on your device."
                    )

                    MarkdownText(markdown: "Created by **Luiz Pizzato** as a fun, vibe-driven coding experiment with [OpenAI’s Codex](https://openai.com/codex/). It’s released as **open source**, so anyone is welcome to explore, adapt, and modify it. More details and reflections are shared in this [Medium story](https://medium.com/placeholder-link)."

                    )

                    Divider()

                    // INSPIRATION
                    Text("Inspiration and attributions")
                        .font(.headline)

                    MarkdownText(markdown:
                        "Inspired by [Lingcam by Masaru Mizuochi](https://lingcam.mizumasa.net/), presented at [CVPR 2025 AI Art](https://thecvf-art.com/project/lingcam/)."
                    )

                    MarkdownText(markdown:
                        "The project starting point was Apple’s [FastVLM repository](https://github.com/apple/ml-fastvlm), which introduced efficient vision encoding for vision-language models also at a [CVPR 2025 paper](https://openaccess.thecvf.com/content/CVPR2025/html/Vasu_FastVLM_Efficient_Vision_Encoding_for_Vision_Language_Models_CVPR_2025_paper.html)."
                    )
                    MarkdownText(markdown:
                        "The image generation is done with [Apple Intelligence Playground](https://developer.apple.com/machine-learning/apple-intelligence-playground/) enabling a fully offline, on-device AI experience."
                    )

                    Divider()

                    // DISCLAIMER
                    Text("Disclaimer")
                        .font(.headline)

                    MarkdownText(markdown:
                        "This project is provided **as is**, without warranty of any kind. Use at your own risk. No guarantees are made regarding accuracy, reliability, or fitness for any purpose. By using this app, you agree that the developer is not liable for any outcomes, damages, or issues arising from its use."
                    )
                    
                    Divider()

                    // DISCLAIMER
                    Text("Open source and Software Licenses")
                        .font(.headline)

                    MarkdownText(markdown:
                        "This project was built on top of Apple's [FastVLM](https://github.com/apple/ml-fastvlm), see the [README](https://github.com/apple/ml-fastvlm/blob/main/README.md) for more details."
                    )

                }
                .padding()
            }
            .navigationTitle("About")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
}
