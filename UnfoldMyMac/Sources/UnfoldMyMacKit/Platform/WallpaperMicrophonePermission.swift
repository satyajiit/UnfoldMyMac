enum WallpaperMicrophonePermission: String, Sendable {
    case undetermined = "Microphone access has not been requested."
    case authorized = "Microphone access allowed."
    case denied = "Microphone access denied. Allow it in System Settings → Privacy & Security → Microphone."
    case restricted = "Microphone access is restricted on this Mac."
}
