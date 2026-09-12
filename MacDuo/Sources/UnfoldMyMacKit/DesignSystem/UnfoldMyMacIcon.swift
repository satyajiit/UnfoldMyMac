import SwiftUI

/// One semantic SF Symbols vocabulary for navigation, actions and state. Effects name their own symbol in
/// `Effects.json`; add names here instead of scattering string literals or drawing replacement icons.
enum UnfoldMyMacIcon: String, CaseIterable {
    case brand = "circle.lefthalf.filled"
    case effects = "square.grid.2x2"
    case wallpaper = "rectangle.on.rectangle.angled"
    case connection = "point.3.connected.trianglepath.dotted"
    case motion = "waveform.path"
    case settings = "slider.horizontal.3"
    case appSettings = "gearshape"
    case image = "photo"
    case clear = "xmark.circle.fill"
    case search = "magnifyingglass"
    case importImage = "photo.badge.plus"
    case folder = "folder"
    case trash = "trash"
    case more = "ellipsis.circle"
    case rename = "pencil"
    case author = "person.crop.circle"
    case display = "display"
    case selected = "checkmark.circle.fill"
    case idle = "pause.circle"
    case play = "play.fill"
    case pause = "pause.fill"
    case stop = "stop.fill"
    case privacy = "lock.shield"
    case warning = "exclamationmark.circle"
    case accessibility = "accessibility"
}

extension Label where Title == Text, Icon == Image {
    init(_ title: String, icon: UnfoldMyMacIcon) { self.init(title, systemImage: icon.rawValue) }
}
