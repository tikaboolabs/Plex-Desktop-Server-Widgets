import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataManager: PlexDataManager
    @State private var serverUrl: String = PlexConfig.shared.serverUrl
    @State private var token: String = PlexConfig.shared.token
    @State private var testStatus: TestStatus = .idle

    enum TestStatus {
        case idle, testing, success(String), failure
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plex Desktop Widgets")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Configure your Plex Media Server connection")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(24)

            Divider().padding(.horizontal, 24)

            // Form
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Server URL")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("http://localhost:32400", text: $serverUrl)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Plex Token")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Link("How to find your token",
                             destination: URL(string: "https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/")!)
                            .font(.system(size: 10))
                    }
                    SecureField("Enter your Plex token", text: $token)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Divider().padding(.horizontal, 24)

            // Actions
            HStack {
                statusView

                Spacer()

                Button("Test") { testConnection() }
                Button("Save") { save() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch testStatus {
        case .idle:
            EmptyView()
        case .testing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Connecting…").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case .success(let name):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(name).font(.system(size: 11, weight: .medium)).foregroundStyle(.green)
            }
        case .failure:
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text("Connection failed").font(.system(size: 11)).foregroundStyle(.red)
            }
        }
    }

    private func testConnection() {
        testStatus = .testing
        PlexConfig.shared.serverUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        PlexConfig.shared.token = token.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            let snapshot = await PlexAPIClient.shared.fetchSnapshot()
            await MainActor.run {
                if snapshot.serverName != "—" {
                    testStatus = .success(snapshot.serverName)
                } else {
                    testStatus = .failure
                }
            }
        }
    }

    private func save() {
        PlexConfig.shared.serverUrl = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        PlexConfig.shared.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        dataManager.fetch()
    }
}
