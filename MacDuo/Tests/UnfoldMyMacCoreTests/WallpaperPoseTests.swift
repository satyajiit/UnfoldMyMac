import Foundation
import Testing
@testable import UnfoldMyMacCore

private func template(channels: [WallpaperChannel]? = nil, grid: String? = nil) throws -> WallpaperTemplate {
    var json: [String: Any] = ["version": 1, "id": "pose", "title": "Pose", "subtitle": "", "author": "", "tags": [], "shader": "pulse",
        "accent": 0xFFFFFF, "background": 0x101010, "reactiveMetric": "mac.cpu", "reactiveScale": 50,
        "layers": [["id": "a", "kind": "text", "content": "x", "format": "text", "x": 0, "y": 0, "width": 0.5, "size": 0.03, "color": 0xFFFFFF, "rotation": 0]]]
    if let channels { json["channels"] = channels.map { ["metric": $0.metric, "scale": $0.scale] } }
    if let grid { json["gridBinding"] = grid }
    return try JSONDecoder().decode(WallpaperTemplate.self, from: JSONSerialization.data(withJSONObject: json)).validated()
}

@Test func poseScalesEnergyClampsChannelsAndReadsTheGrid() throws {
    let now = Date()
    var snapshot = WallpaperSnapshot()
    snapshot.sources["mac"] = .init(timestamp: now, numbers: ["mac.cpu": 25, "mac.memory": 200, "mac.load": -3],
                                    grids: ["mac.map": WallpaperScalarGrid(revision: "r1", width: 1, height: 1, values: [0.5])])
    let plain = WallpaperPose(template: try template(), snapshot: snapshot, at: now)
    #expect(plain.energy == 0.5 && plain.channels == .zero && plain.grid == nil)
    let bound = try template(channels: [.init(metric: "mac.memory", scale: 100), .init(metric: "mac.load", scale: 1), .init(metric: "mac.missing", scale: 1)], grid: "mac.map")
    let pose = WallpaperPose(template: bound, snapshot: snapshot, at: now)
    #expect(pose.channels == SIMD4<Float>(1, 0, 0, 0), "Channels clamp to 0...1 and a missing metric reads as zero")
    #expect(pose.grid?.revision == "r1")
    #expect(WallpaperPose(template: bound, snapshot: WallpaperSnapshot(), at: now) == WallpaperPose())
    #expect(WallpaperPose(template: bound, snapshot: snapshot, at: now.addingTimeInterval(3600)).energy == 0, "Stale samples do not drive the scene")
}

@Test func refreshScheduleRetriesSoonerAfterFailureAndClearsItOnSuccess() {
    var schedule = RefreshSchedule(refreshInterval: 300, retryInterval: 60)
    let start = Date()
    #expect(schedule.isDue(at: start))
    schedule.succeeded(at: start)
    #expect(!schedule.isDue(at: start.addingTimeInterval(299)) && schedule.isDue(at: start.addingTimeInterval(300)) && schedule.failure == nil)
    schedule.failed("offline", at: start.addingTimeInterval(300))
    #expect(schedule.failure == "offline")
    #expect(!schedule.isDue(at: start.addingTimeInterval(359)) && schedule.isDue(at: start.addingTimeInterval(360)))
    schedule.succeeded(at: start.addingTimeInterval(360))
    #expect(schedule.failure == nil && !schedule.isDue(at: start.addingTimeInterval(400)))
}
