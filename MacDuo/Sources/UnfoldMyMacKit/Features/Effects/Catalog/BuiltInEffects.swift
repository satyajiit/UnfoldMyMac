import UnfoldMyMacCore

/// Native effects register metadata and a renderer factory here. The library,
/// menus, session, and preview discover them without switches on effect IDs.
@MainActor enum BuiltInEffects {
    static var registrations: [EffectRegistration] { [
        .init(descriptor: .init(id: .frost, title: "Frost", subtitle: "A softer close.",
            detail: "Your desktop stays in place as a soft blur deepens toward the upper edge. Inspired by the iPhone Duo transition.",
            symbol: UnfoldMyMacIcon.frost.rawValue, requiresCapture: true, tags: ["Glass", "Blur", "Calm"],
            coverURL: LibraryAssets.url("Frost", folder: "Covers")),
            makeRenderer: EffectRegistration.metal { try FrostPipeline(gpu: $0) }),
        .init(descriptor: .init(id: .veil, title: "Veil", subtitle: "A quiet layer of glass.",
            detail: "A translucent native material settles over your desktop, with a soft neutral tint. No Screen Recording needed.",
            symbol: UnfoldMyMacIcon.veil.rawValue, tags: ["Glass", "Minimal", "Calm"], coverURL: LibraryAssets.url("Veil", folder: "Covers")),
            makeRenderer: { _ in NativeEffectRenderer(kind: .veil) }),
        .init(descriptor: .init(id: .fade, title: "Fade", subtitle: "Ease into the dark.",
            detail: "A smooth shade follows the lid toward a gentle blackout. No Screen Recording needed.",
            symbol: UnfoldMyMacIcon.fade.rawValue, tags: ["Minimal", "Dark", "Calm"], coverURL: LibraryAssets.url("Fade", folder: "Covers")),
            makeRenderer: { _ in NativeEffectRenderer(kind: .fade) }),
        .init(descriptor: .init(id: .curtains, title: "Curtains", subtitle: "Every close deserves a curtain call.",
            detail: "Garnet velvet draws in from both sides. Sculpted folds catch the stage lights as the curtains meet, then gather away when you open the lid.",
            symbol: UnfoldMyMacIcon.curtains.rawValue, parameterTitle: "Fold depth", renderingLabel: "3D velvet", category: .motion,
            tags: ["3D", "Theatre", "Cinematic"], coverURL: LibraryAssets.url("Curtains", folder: "Covers")),
            makeRenderer: EffectRegistration.metal { try CurtainsPipeline(gpu: $0) }),
        .init(descriptor: .init(id: .current, title: "Current", subtitle: "A little life in every opening.",
            detail: "Luminous mint and coral ribbons flow around a widening opening. Drifting sparks and soft waves keep the scene alive while your lid holds still. Reduce Motion stills the flow.",
            symbol: UnfoldMyMacIcon.current.rawValue, parameterTitle: "Flow energy", renderingLabel: "Living motion", category: .motion,
            tags: ["Animated", "Abstract", "Energetic", "Neon"], coverURL: LibraryAssets.url("Current", folder: "Covers"), hasContinuousMotion: true),
            makeRenderer: EffectRegistration.metal { try CurrentPipeline(gpu: $0) }),
        .init(descriptor: .init(id: EffectID(rawValue: "peekaboo"), title: "Peekaboo", subtitle: "Your desktop has an audience.",
            detail: "Two glossy, mischievous shutters peek in from the edges. Their googly eyes look around and blink as the soft 3D faces breathe. Open the lid and they slide away. Reduce Motion stills the faces.",
            symbol: UnfoldMyMacIcon.peekaboo.rawValue, parameterTitle: "Playfulness", renderingLabel: "3D characters", category: .motion,
            tags: ["3D", "Animated", "Humor", "Characters", "Playful"], coverURL: LibraryAssets.url("Peekaboo", folder: "Covers"), hasContinuousMotion: true),
            makeRenderer: EffectRegistration.metal { try PeekabooPipeline(gpu: $0) })
    ] }
}
