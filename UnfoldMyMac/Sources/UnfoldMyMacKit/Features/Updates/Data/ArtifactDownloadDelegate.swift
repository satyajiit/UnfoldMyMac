import Foundation
import Synchronization
import UnfoldMyMacCore

/// Receives the transfer callbacks for one disk image.
///
/// `URLSessionDelegate` is `Sendable`, so this class can hold no mutable stored property; everything
/// lives behind one `Mutex`, the pattern `HTTPConditionalCache` already uses. The completion is
/// resolved in `didCompleteWithError` and nowhere else — finishing early in `didFinishDownloadingTo`
/// is the classic way to resume a continuation twice.
final class ArtifactDownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
    /// No release is remotely this size. A hostile or broken endpoint must not fill the disk.
    static let byteCeiling: Int64 = 256 * 1024 * 1024
    private static let redirectLimit = 5

    private struct State {
        var continuation: AsyncThrowingStream<DownloadEvent, any Error>.Continuation?
        var gate = DownloadProgressGate()
        var landed = false
        var redirects = 0
        var failure: UpdateError?
    }
    private let state = Mutex(State())
    private let destination: URL
    private let resumeDataURL: URL

    init(destination: URL, resumeDataURL: URL) {
        self.destination = destination; self.resumeDataURL = resumeDataURL
    }

    func attach(_ continuation: AsyncThrowingStream<DownloadEvent, any Error>.Continuation) {
        state.withLock { $0.continuation = continuation }
    }

    /// Must not suspend: the header states the downloaded file is removed once this returns.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            state.withLock { $0.landed = true }
        } catch {
            state.withLock { $0.failure = .downloadCouldNotBeSaved }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > Self.byteCeiling || totalBytesWritten > Self.byteCeiling {
            state.withLock { $0.failure = .downloadTooLarge }
            downloadTask.cancel()
            return
        }
        let publish = state.withLock {
            $0.gate.shouldPublish(received: totalBytesWritten, total: totalBytesExpectedToWrite,
                                  at: ProcessInfo.processInfo.systemUptime)
        }
        guard publish else { return }
        state.withLock { $0.continuation }?
            .yield(.progress(received: totalBytesWritten, expected: totalBytesExpectedToWrite))
    }

    /// GitHub sends release downloads on to a signed object URL. Following that is expected; leaving
    /// HTTPS, or looping, is not.
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        let allowed = state.withLock { state -> Bool in
            state.redirects += 1
            return state.redirects <= Self.redirectLimit
        }
        guard allowed, request.url?.scheme == "https" else {
            state.withLock { $0.failure = .unexpectedRedirect }
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }

    /// Always last, on success and on failure alike.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let data = (error as? NSError)?.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            try? FileManager.default.createDirectory(at: resumeDataURL.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true,
                                                     attributes: [.posixPermissions: 0o700])
            try? data.write(to: resumeDataURL, options: .atomic)
        }
        let (continuation, landed, failure) = state.withLock { state -> (AsyncThrowingStream<DownloadEvent, any Error>.Continuation?, Bool, UpdateError?) in
            defer { state.continuation = nil }
            return (state.continuation, state.landed, state.failure)
        }
        if let failure {
            continuation?.finish(throwing: failure)
        } else if let error {
            continuation?.finish(throwing: UpdateNetworkError.mapped(error))
        } else if landed {
            continuation?.yield(.finished)
            continuation?.finish()
        } else {
            continuation?.finish(throwing: UpdateError.downloadCouldNotBeSaved)
        }
    }
}
