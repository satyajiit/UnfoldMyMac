import Foundation
import UnfoldMyMacCore

enum DownloadEvent: Sendable, Equatable {
    case progress(received: Int64, expected: Int64)
    case finished
}

/// Fetches the disk image, reporting progress and surviving an interrupted connection.
protocol ArtifactDownloading: Sendable {
    /// Cancelling the consuming task cancels the transfer and keeps whatever can be resumed.
    func download(_ release: UpdateRelease, to destination: URL,
                  resumeAt resumeData: URL) -> AsyncThrowingStream<DownloadEvent, any Error>
}
