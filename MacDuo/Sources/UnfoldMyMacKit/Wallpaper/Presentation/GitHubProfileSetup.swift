import SwiftUI

struct GitHubProfileSetup: View {
    @Binding var connection: WallpaperConnectionSettings
    @State private var username: String
    @State private var profile: GitHubProfile?
    @State private var loading = false
    @State private var error: String?
    @State private var request: Task<Void, Never>?

    init(connection: Binding<WallpaperConnectionSettings>) {
        _connection = connection
        _username = State(initialValue: connection.wrappedValue.username ?? "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose the public profile this city should follow. A username is enough; GitHub sign-in is not needed for public stats.")
                .modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                TextField("GitHub username or profile URL", text: $username)
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("wallpaper.github.username")
                    .onSubmit { lookup() }
                Button("Find profile") { lookup() }.disabled(loading || username.trimmingCharacters(in: .whitespaces).isEmpty)
                    .modifier(UnfoldMyMacButtonStyle()).fixedSize()
            }
            .onChange(of: username) { _, _ in
                request?.cancel(); profile = nil; error = nil; loading = false; connection = .init()
            }
            if loading { ProgressView("Finding your profile…") }
            if let error { Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            if let profile {
                VStack(alignment: .leading, spacing: 8) {
                    Label("@" + profile.login, systemImage: "checkmark.circle.fill").font(UnfoldMyMacType.headline)
                    Text("\(profile.public_repos) public repos · \(profile.followers) followers").modifier(SecondaryTextStyle())
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    .background(.quaternary, in: .rect(cornerRadius: 12))
            } else if connection.enabled, let username = connection.username {
                Label("Connected to @" + username, systemImage: "checkmark.circle.fill")
            }
            Text("Public repos, followers and recent push events refresh every five minutes. GitHub's event feed may be delayed.")
                .font(UnfoldMyMacType.caption).modifier(SecondaryTextStyle()).fixedSize(horizontal: false, vertical: true)
            if connection.enabled {
                Button("Disconnect profile") { username = ""; connection = .init(); profile = nil }.buttonStyle(.plain)
            }
        }.onDisappear { request?.cancel() }
    }
    private func lookup() {
        request?.cancel(); profile = nil; error = nil; loading = true
        let input = username
        request = Task {
            do {
                let found = try await GitHubProfileClient().profile(input)
                guard !Task.isCancelled else { return }
                profile = found; loading = false
                connection = .init(enabled: true, username: found.login)
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription; loading = false
            }
        }
    }
}
