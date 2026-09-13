import Foundation
import UnfoldMyMacCore

/// Downloads the disk image through a session of its own.
///
/// A download task rather than a byte stream, because only a download task can hand back resume data
/// when the connection drops — and re-resolving GitHub's signed object URL by hand on every retry is
/// a problem that never stops. The shared body reader is deliberately not reused: it buffers whole
/// responses in memory for small API payloads, and its session has no delegate.
struct URLSessionArtifactDownloader: ArtifactDownloading {
    var configuration: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60          // stalled, not slow
        configuration.timeoutIntervalForResource = 1800       // the whole transfer
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return configuration
    }()

    func download(_ release: UpdateRelease, to destination: URL,
                  resumeAt resumeData: URL) -> AsyncThrowingStream<DownloadEvent, any Error> {
        AsyncThrowingStream { continuation in
            let delegate = ArtifactDownloadDelegate(destination: destination, resumeDataURL: resumeData)
            delegate.attach(continuation)
            // A session retains its delegate until it is invalidated, so each download owns one and
            // finishes it; sharing one here would leak a delegate and its sockets on every check.
            let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            var request = URLRequest(url: release.assetURL)
            request.setValue(AppIdentity.name, forHTTPHeaderField: "User-Agent")
            let resumable = try? Data(contentsOf: resumeData)
            let task = resumable.map(session.downloadTask(withResumeData:)) ?? session.downloadTask(with: request)

            continuation.onTermination = { reason in
                switch reason {
                case .cancelled:
                    // Keep what can be resumed; the delegate writes the blob when the cancel lands.
                    task.cancel(byProducingResumeData: { data in
                        if let data { try? data.write(to: resumeData, options: .atomic) }
                    })
                default:
                    break
                }
                session.finishTasksAndInvalidate()
            }
            task.resume()
        }
    }
}
