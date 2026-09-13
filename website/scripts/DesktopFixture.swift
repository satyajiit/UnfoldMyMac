import AppKit
import SwiftUI

/// Anonymous desktop content shared with the updated README previews. All names and window contents are fixtures.
@MainActor
struct DesktopFixture: View {
    private let resources = URL(fileURLWithPath: "UnfoldMyMac/Sources/UnfoldMyMacKit/Resources")
    private let ink = Color(red: 0.13, green: 0.15, blue: 0.19)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(nsImage: NSImage(contentsOfFile: "/System/Library/Desktop Pictures/Sonoma.heic")!)
                .resizable().scaledToFill().frame(width: 1280, height: 800).clipped()
            menuBar
            desktopFolder("Wallpapers", x: 1170, y: 103)
            desktopFolder("Definitely final", x: 1170, y: 223)
            notesWindow.offset(x: 635, y: 280)
            finderWindow.offset(x: 154, y: 121)
            dock.position(x: 640, y: 748)
        }
        .frame(width: 1280, height: 800).clipped()
        .environment(\.colorScheme, .light)
    }

    private var menuBar: some View {
        HStack(spacing: 23) {
            Image(systemName: "apple.logo").font(.system(size: 17))
            Text("Finder").fontWeight(.bold)
            ForEach(["File", "Edit", "View", "Go", "Window", "Help"], id: \.self) { Text($0) }
            Spacer()
            Image(systemName: "battery.100percent").font(.system(size: 21))
            Image(systemName: "wifi")
            Image(systemName: "magnifyingglass")
            Image(systemName: "switch.2")
            Text("Sat 12 Sep  9:41 AM")
        }
        .font(.system(size: 14)).foregroundStyle(.white)
        .padding(.horizontal, 23).frame(height: 31)
        .background(.black.opacity(0.23))
    }

    private func desktopFolder(_ title: String, x: CGFloat, y: CGFloat) -> some View {
        VStack(spacing: 5) {
            Image(nsImage: NSWorkspace.shared.icon(for: .folder)).resizable().frame(width: 65, height: 65)
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(.white)
                .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
        }.frame(width: 130).position(x: x, y: y)
    }

    private var trafficLights: some View {
        HStack(spacing: 8) {
            ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.75, blue: 0.18), Color(red: 0.16, green: 0.79, blue: 0.26)], id: \.self) { color in
                Circle().fill(color).overlay(Circle().strokeBorder(.black.opacity(0.1), lineWidth: 0.7)).frame(width: 13, height: 13)
            }
        }
    }

    private var finderWindow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 23) {
                trafficLights.padding(.trailing, 26)
                Image(systemName: "chevron.left").foregroundStyle(.secondary)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                Text("Weekend project").fontWeight(.semibold)
                Spacer()
                Image(systemName: "square.grid.2x2")
                Image(systemName: "square.and.arrow.up")
                Image(systemName: "magnifyingglass")
            }.font(.system(size: 15)).padding(.horizontal, 20).frame(height: 57)
                .background(Color(white: 0.965))
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 19) {
                    Text("Favorites").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    sidebarRow("clock", "Recents")
                    sidebarRow("airplayaudio", "AirDrop")
                    sidebarRow("app.badge", "Applications")
                    sidebarRow("desktopcomputer", "Desktop")
                    sidebarRow("doc", "Documents")
                    sidebarRow("arrow.down.circle", "Downloads")
                    Text("iCloud").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).padding(.top, 12)
                    sidebarRow("icloud", "iCloud Drive")
                    Spacer()
                }.padding(18).frame(width: 175).background(Color(red: 0.90, green: 0.92, blue: 0.91))
                VStack(spacing: 32) {
                    HStack(spacing: 29) {
                        fileTile("Reverie.png", artwork: "Reverie")
                        fileTile("Neon Coast.png", artwork: "NeonCoast")
                        fileTile("Rise.png", artwork: "Rise")
                    }
                    HStack(spacing: 29) {
                        folderTile("Effects")
                        folderTile("Live wallpapers")
                        folderTile("Screenshots")
                    }
                    Spacer()
                }.padding(.top, 32).frame(maxWidth: .infinity)
            }.frame(height: 322)
            HStack { Text("6 items"); Spacer(); Image(systemName: "slider.horizontal.3") }
                .font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 18).frame(height: 27)
                .background(Color(white: 0.97))
        }
        .foregroundStyle(ink).frame(width: 672).background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.55), lineWidth: 1))
        .compositingGroup()
        .shadow(color: .black.opacity(0.27), radius: 25, y: 17)
    }

    private func sidebarRow(_ symbol: String, _ name: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).frame(width: 15).foregroundStyle(.blue)
            Text(name)
        }.font(.system(size: 13))
    }

    private func fileTile(_ name: String, artwork: String) -> some View {
        VStack(spacing: 10) {
            Image(nsImage: NSImage(contentsOf: resources.appendingPathComponent("Artwork/\(artwork).png"))!)
                .resizable().scaledToFill().frame(width: 98, height: 67).clipped()
                .padding(3).background(.white).shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            Text(name).font(.system(size: 12))
        }.frame(width: 119)
    }

    private func folderTile(_ name: String) -> some View {
        VStack(spacing: 5) {
            Image(nsImage: NSWorkspace.shared.icon(for: .folder)).resizable().frame(width: 77, height: 67)
            Text(name).font(.system(size: 12))
        }.frame(width: 119)
    }

    private var notesWindow: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { trafficLights; Spacer(); Text("weekend-project.txt").fontWeight(.medium); Spacer() }
                .font(.system(size: 13)).padding(.horizontal, 17).frame(height: 40).background(Color(white: 0.965))
            Text("THE PLAN\n\n1. Make one lid effect.\n2. Definitely stop there.\n3. Build a wallpaper engine.\n\n...that escalated quickly.")
                .font(.system(size: 17, design: .monospaced)).lineSpacing(8).padding(28)
            Spacer()
        }
        .foregroundStyle(ink).frame(width: 449, height: 322).background(Color(white: 0.995))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.6), lineWidth: 1))
        .compositingGroup()
        .shadow(color: .black.opacity(0.24), radius: 22, y: 12)
    }

    private var dock: some View {
        HStack(spacing: 10) {
            dockIcon("/System/Library/CoreServices/Finder.app", running: true)
            dockIcon("/Applications/Safari.app")
            dockIcon("/System/Applications/Messages.app")
            dockIcon("/System/Applications/Mail.app")
            dockIcon("/System/Applications/Photos.app")
            dockIcon("/System/Applications/Notes.app")
            dockIcon("/System/Applications/Utilities/Terminal.app", running: true)
            Image(nsImage: NSImage(contentsOf: resources.appendingPathComponent("Brand/UnfoldMyMacLogo.png"))!)
                .resizable().frame(width: 53, height: 53).clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.bottom, 4)
            Rectangle().fill(.white.opacity(0.35)).frame(width: 1, height: 46).padding(.horizontal, 3)
            Image(nsImage: NSImage(contentsOfFile: "/System/Library/CoreServices/Dock.app/Contents/Resources/trashempty@2x.png")!)
                .resizable().scaledToFit().frame(width: 52, height: 54).padding(.bottom, 5)
        }
        .padding(.horizontal, 15).padding(.vertical, 7)
        .background(.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.4), lineWidth: 1))
        .compositingGroup()
        .shadow(color: .black.opacity(0.20), radius: 12, y: 6)
    }

    private func dockIcon(_ path: String, running: Bool = false) -> some View {
        VStack(spacing: 0) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 57, height: 57)
            Circle().fill(.white.opacity(running ? 0.9 : 0)).frame(width: 4, height: 4)
        }
    }
}
