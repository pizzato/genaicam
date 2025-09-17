//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation

/// Helper responsible for downloading large model archives while reporting progress.
final class ModelDownloader: NSObject, URLSessionDownloadDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    private var progressHandler: ((Int64, Int64) -> Void)?
    private var destinationURL: URL?
    private var session: URLSession?
    private var lastUpdate = Date.distantPast

    /// Downloads a remote file to a local destination while calling the provided progress handler.
    /// - Parameters:
    ///   - url: Source URL.
    ///   - destinationURL: Destination URL. Any existing file at this location will be replaced.
    ///   - progress: Closure invoked periodically with the number of received bytes and the total byte count.
    func download(from url: URL, to destinationURL: URL, progress: @escaping (Int64, Int64) -> Void) async throws {
        self.destinationURL = destinationURL
        self.progressHandler = progress

        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let now = Date()
        if now.timeIntervalSince(lastUpdate) >= 1 || totalBytesWritten == totalBytesExpectedToWrite {
            lastUpdate = now
            progressHandler?(totalBytesWritten, totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        do {
            guard let destinationURL else {
                continuation?.resume(throwing: URLError(.unknown))
                return
            }

            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            continuation?.resume(returning: ())
        } catch {
            continuation?.resume(throwing: error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error {
            continuation?.resume(throwing: error)
        }
        session.invalidateAndCancel()
        continuation = nil
        progressHandler = nil
        destinationURL = nil
        self.session = nil
        lastUpdate = .distantPast
    }
}
