import Foundation

/// Actual host features, derived from runtime declarations rather than promotional tags.
public enum ContentCapability: String, CaseIterable, Identifiable, Sendable {
    case lid, motion, microphone, network, publicAPI, localFiles, hooks, macMetrics, openApps
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .lid: "Lid sensor"
        case .motion: "Motion sensors"
        case .microphone: "Microphone"
        case .network: "Network"
        case .publicAPI: "Public API"
        case .localFiles: "Local files"
        case .hooks: "Local hooks"
        case .macMetrics: "Mac metrics"
        case .openApps: "Open apps"
        }
    }
    public var symbol: String {
        switch self {
        case .lid: "laptopcomputer"
        case .motion: "gyroscope"
        case .microphone: "mic"
        case .network: "network"
        case .publicAPI: "globe"
        case .localFiles: "folder"
        case .hooks: "bolt.horizontal"
        case .macMetrics: "cpu"
        case .openApps: "square.stack.3d.up"
        }
    }
    public var detail: String {
        switch self {
        case .lid: "Responds to the angle of your MacBook lid."
        case .motion: "Optional physical motion input on supported Macs."
        case .microphone: "Responds to sound when enabled. Permission is requested in setup; audio is not recorded."
        case .network: "Connects to a configured service while the design is in use."
        case .publicAPI: "Reads public data from the source described below."
        case .localFiles: "Reads the local data you connect in setup."
        case .hooks: "Responds to local tool lifecycle events after setup."
        case .macMetrics: "Uses local Mac activity such as CPU load."
        case .openApps: "Counts ordinary open apps locally. App names and window contents are not retained."
        }
    }
}
