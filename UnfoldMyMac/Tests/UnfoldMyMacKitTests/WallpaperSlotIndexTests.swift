import Foundation
import Testing
import UnfoldMyMacCore
@testable import UnfoldMyMacKit

/// Reading the system's own wallpaper store, which is the only thing that knows what the user chose for
/// the lock screen at a moment when the lock screen is not being shown.
@MainActor private func store(_ root: [String: Any]) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("WallpaperSlotIndexTests/\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("Index.plist")
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try PropertyListSerialization.data(fromPropertyList: root, format: .binary, options: 0).write(to: url)
    return url
}
private func slot(_ provider: String) -> [String: Any] {
    ["Content": ["Choices": [["Provider": provider, "Files": [], "Configuration": Data()]]]]
}
private let ours = AppIdentity.wallpaperExtensionIdentifier

@Test @MainActor func theIdleSlotIsWhatSaysTheLockScreenIsOurs() throws {
    // Desktop ours, Idle Apple's: this is the state the app used to report as "on your lock screen", and
    // the lock screen was painting an exported still of the Aerials choice the whole time.
    let desktopOnly = try store(["Displays": ["A": ["Desktop": slot(ours), "Idle": slot("com.apple.wallpaper.choice.aerials")]]])
    #expect(WallpaperSlotIndex.coversLockScreen(at: desktopOnly) == false)

    let both = try store(["Displays": ["A": ["Desktop": slot(ours), "Idle": slot(ours)]]])
    #expect(WallpaperSlotIndex.coversLockScreen(at: both) == true)

    // macOS keeps a shared Idle slot beside the per-display ones; either naming us is enough.
    let shared = try store(["AllSpacesAndDisplays": ["Idle": slot(ours)],
                            "Displays": ["A": ["Desktop": slot(ours), "Idle": slot("com.apple.wallpaper.choice.aerials")]]])
    #expect(WallpaperSlotIndex.coversLockScreen(at: shared) == true)

    // One display of several is enough: the lock screen is ours somewhere.
    let mixed = try store(["Displays": ["A": ["Idle": slot("com.apple.wallpaper.choice.aerials")], "B": ["Idle": slot(ours)]]])
    #expect(WallpaperSlotIndex.coversLockScreen(at: mixed) == true)
}

@Test @MainActor func aStoreThisBuildCannotReadAnswersNothingRatherThanNo() throws {
    // This is a private format read defensively. A macOS release that reshapes it must leave the app
    // saying "I don't know" — answering "no" would send the user to System Settings to fix a setting
    // they already made, and answering "yes" would promise a lock screen on no evidence at all.
    #expect(WallpaperSlotIndex.coversLockScreen(at: URL(fileURLWithPath: "/nonexistent/Index.plist")) == nil)
    #expect(try WallpaperSlotIndex.coversLockScreen(at: store([:])) == nil, "No Idle slot anywhere is a shape we do not understand")
    #expect(try WallpaperSlotIndex.coversLockScreen(at: store(["Displays": ["A": ["Idle": ["Content": "not a dictionary"]]]])) == false,
            "A slot we can find but whose choices we cannot read names no provider, so it is not ours")
}
