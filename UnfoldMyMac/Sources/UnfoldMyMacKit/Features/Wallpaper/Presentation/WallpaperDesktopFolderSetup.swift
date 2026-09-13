import SwiftUI
import UnfoldMyMacCore

struct WallpaperDesktopFolderSetup: View {
    @Binding var connection: WallpaperConnectionSettings
    @Environment(\.filePicker) private var filePicker
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Let the items on your Desktop fill the workshop's shelves. Files, folders and shortcuts each count once; their contents are never opened.")
                .font(UnfoldMyMacType.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if connection.folderBookmark != nil {
                Toggle("Use folder items", isOn: $connection.enabled).accessibilityIdentifier("workshop.folder.enabled")
                Label(connection.path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Connected folder", systemImage: "folder")
                    .font(UnfoldMyMacType.callout)
            }
            HStack {
                Button(connection.folderBookmark == nil ? "Use Desktop items…" : "Choose folder…", action: chooseFolder)
                    .accessibilityIdentifier("workshop.folder.choose")
                if connection.folderBookmark != nil {
                    Button("Disconnect") { connection = .init(); error = nil }
                        .accessibilityIdentifier("workshop.folder.disconnect")
                }
            }
            if let error { Text(error).font(UnfoldMyMacType.callout).foregroundStyle(.red).accessibilityIdentifier("workshop.folder.error") }
            Text("You can also choose another folder. Only its immediate items are counted. Finder stacks and mounted drives do not change this count.")
                .font(UnfoldMyMacType.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chooseFolder() {
        let request = FilePickerRequest(title: "Choose the workshop's folder", prompt: "Use folder",
            message: "Choose Desktop, or another folder whose item count will fill the shelves. File contents are never read.",
            types: [], directories: true, directoryURL: FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first)
        filePicker.pick(request) { url in
            guard let url else { return }
            do {
                let bookmark = try WorkshopFolderAccess.bookmark(for: url)
                connection = .init(enabled: true, path: url.path, folderBookmark: bookmark)
                error = nil
            } catch { self.error = "This folder could not be connected. Choose it again to allow access." }
        }
    }
}
