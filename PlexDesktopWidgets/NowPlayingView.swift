import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var data: PlexDataManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.wSeparator)

            if !PlexConfig.shared.isConfigured {
                setupPrompt
            } else if data.streams.isEmpty {
                emptyState
            } else {
                streamsList
            }
        }
        .frame(width: 340)
        .widgetBackground()
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.plexGold)
            Text("Now Playing")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color.wText)
            Spacer()
            if !data.streams.isEmpty {
                Text("\(data.streams.count) stream\(data.streams.count == 1 ? "" : "s")")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.wTextDim)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Streams
    private var streamsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(data.streams.enumerated()), id: \.element.id) { index, stream in
                StreamRow(stream: stream)
                if index < data.streams.count - 1 {
                    Divider().background(Color.wSeparator).padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Empty
    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "play.slash")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.white.opacity(0.12))
            Text("Nothing playing")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.wTextDim)
            Text("Streams will appear here")
                .font(.system(size: 10))
                .foregroundStyle(Color.wTextFaint)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    // MARK: - Setup
    private var setupPrompt: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "gear")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.white.opacity(0.15))
            Text("Open Settings to connect")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.wTextDim)
            Text("Click the ▶ menu bar icon → Settings")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.wTextFaint)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }
}

// MARK: - Stream Row
struct StreamRow: View {
    let stream: PlexStream

    private var typeIcon: String {
        switch stream.mediaType {
        case .tv: return "tv"
        case .movie: return "film"
        case .music: return "music.note"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Poster thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.wCardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.wSeparator, lineWidth: 0.5)
                    )

                if let thumbUrl = stream.thumbUrl {
                    PosterImage(url: thumbUrl)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: typeIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.wTextDim)
                }

                // Playing indicator pill
                if stream.state == .playing {
                    VStack {
                        Spacer()
                        HStack(spacing: 1.5) {
                            ForEach(0..<3, id: \.self) { i in
                                EQBar(delay: Double(i) * 0.15)
                            }
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.black.opacity(0.65)))
                        .padding(.bottom, 3)
                    }
                }
            }
            .frame(width: 48, height: 70)

            VStack(alignment: .leading, spacing: 0) {
                Text(stream.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.wText)
                    .lineLimit(1)

                Text(stream.subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.wTextMid)
                    .lineLimit(1)
                    .padding(.top, 1)

                HStack(spacing: 4) {
                    Text(stream.user).foregroundStyle(Color.wTextMid)
                    Text("·").foregroundStyle(Color.wTextFaint)
                    Text(stream.player).foregroundStyle(Color.wTextDim)
                }
                .font(.system(size: 9.5, weight: .medium))
                .lineLimit(1)
                .padding(.top, 3)

                // Progress bar
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.wTrack)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [.plexGold, .plexGold.opacity(0.8)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: geo.size.width * CGFloat(min(max(stream.progress, 0), 1)))
                        }
                    }
                    .frame(height: 2.5)

                    Text(stream.remainingFormatted)
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.wTextDim)
                        .frame(minWidth: 36, alignment: .trailing)
                }
                .padding(.top, 6)

                // Badges row
                HStack(spacing: 4) {
                    Badge(text: stream.quality)
                    if stream.isTranscoding {
                        Badge(text: "Transcode", highlight: true)
                    }
                    Spacer()
                    if stream.bandwidthMbps > 0 {
                        Text(String(format: "%.1f Mbps", stream.bandwidthMbps))
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(Color.wTextDim)
                    }
                    Circle()
                        .fill(stream.state == .playing ? Color.plexGreen : Color.plexAmber)
                        .frame(width: 5, height: 5)
                        .shadow(color: (stream.state == .playing ? Color.plexGreen : Color.plexAmber).opacity(0.5), radius: 2)
                }
                .padding(.top, 5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Poster Image Cache + Loader
private final class PosterCache {
    static let shared = PosterCache()
    private let cache = NSCache<NSString, NSImage>()
    private let session: URLSession

    private init() {
        cache.countLimit = 32
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6
        session = URLSession(configuration: config, delegate: InsecureDelegate.shared, delegateQueue: nil)
    }

    func image(for url: String) async -> NSImage? {
        let key = url as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let requestUrl = URL(string: url) else { return nil }
        do {
            let (data, _) = try await session.data(from: requestUrl)
            if let nsImage = NSImage(data: data) {
                cache.setObject(nsImage, forKey: key)
                return nsImage
            }
        } catch {}
        return nil
    }
}

struct PosterImage: View {
    let url: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .onAppear { loadImage() }
        .onChange(of: url) { _, _ in loadImage() }
    }

    private func loadImage() {
        Task {
            if let loaded = await PosterCache.shared.image(for: url) {
                await MainActor.run { self.image = loaded }
            }
        }
    }
}

// MARK: - Badge
struct Badge: View {
    let text: String
    var highlight: Bool = false

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 8.5, weight: .bold))
            .tracking(0.3)
            .foregroundStyle(highlight ? Color.plexGold : Color.wTextMid)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(highlight ? Color.plexGold.opacity(0.12) : Color.wTrack)
            )
    }
}

// MARK: - Equalizer Bar
struct EQBar: View {
    let delay: Double
    @State private var height: CGFloat = 3

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.plexGold)
            .frame(width: 2.5, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay)) {
                    height = 10
                }
            }
    }
}
