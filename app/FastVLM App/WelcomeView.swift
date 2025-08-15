//
//  WelcomeView.swift
//
//  For licensing see accompanying LICENSE file.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "FastVLM"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(appName)
                        .font(.largeTitle)
                        .bold()
                    Text("Version \(appVersion)")
                        .font(.subheadline)
                    Divider()
                    Text("This app is based on:")
                        .font(.headline)
                    Link("ml-fastvlm on GitHub", destination: URL(string: "https://github.com/apple/ml-fastvlm")!)
                    Link("Apple Intelligence Playground", destination: URL(string: "https://developer.apple.com/machine-learning/apple-intelligence-playground/")!)
                    Divider()
                    Text("This app runs entirely on device and does not communicate with any servers.")
                    Text("Author: Luiz Pizzato. This project was made for fun.")
                    Link("Blog post about this project", destination: URL(string: "https://example.com")!)
                }
                .multilineTextAlignment(.leading)
                .padding()
            }
            .navigationTitle("Welcome")
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
