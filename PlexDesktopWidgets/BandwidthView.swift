import SwiftUI

struct BandwidthView: View {
    @EnvironmentObject var data: PlexDataManager

    private var currentTotal: Double { data.bandwidth.last?.totalMbps ?? 0 }
    private var currentLan: Double { data.bandwidth.last?.lanMbps ?? 0 }
    private var currentWan: Double { data.bandwidth.last?.wanMbps ?? 0 }
    private var peak: Double { data.bandwidth.map(\.totalMbps).max() ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.plexGold)
                Text("Bandwidth")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.wText)
                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", currentTotal))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.wText)
                        .contentTransition(.numericText())
                    Text("Mbps")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.wTextDim)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // Chart
            if data.bandwidth.count >= 2 {
                BandwidthChartView(entries: data.bandwidth)
                    .frame(height: 90)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.02))
                    Text(PlexConfig.shared.isConfigured ? "Waiting for data…" : "Configure in Settings")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.wTextFaint)
                }
                .frame(height: 90)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }

            // Footer stats
            Divider().background(Color.wSeparator).padding(.horizontal, 16)

            HStack(spacing: 0) {
                StatCell(label: "LAN", value: currentLan, color: .plexGreen)
                StatCell(label: "WAN", value: currentWan, color: .plexCyan)
                StatCell(label: "PEAK", value: peak, color: .white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 340)
        .widgetBackground()
    }
}

// MARK: - Stat Cell
private struct StatCell: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Color.wTextDim)
            HStack(spacing: 3) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .shadow(color: color.opacity(0.4), radius: 2)
                Text(String(format: "%.1f", value))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .contentTransition(.numericText())
                Text("Mbps")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Canvas Chart
struct BandwidthChartView: View {
    let entries: [BandwidthEntry]

    var body: some View {
        Canvas { context, size in
            guard entries.count >= 2 else { return }
            let maxVal = max((entries.map(\.totalMbps).max() ?? 10) * 1.15, 5)

            var linePath = Path()
            for (i, entry) in entries.enumerated() {
                let x = CGFloat(i) / CGFloat(entries.count - 1) * size.width
                let y = (1 - entry.totalMbps / maxVal) * (size.height - 8) + 4
                if i == 0 { linePath.move(to: CGPoint(x: x, y: y)) }
                else { linePath.addLine(to: CGPoint(x: x, y: y)) }
            }

            // Fill
            var fillPath = linePath
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.addLine(to: CGPoint(x: 0, y: size.height))
            fillPath.closeSubpath()

            context.fill(fillPath, with: .linearGradient(
                Gradient(colors: [
                    Color.plexGold.opacity(0.2),
                    Color.plexGold.opacity(0.04),
                    Color.plexGold.opacity(0),
                ]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
            ))

            // Line
            context.stroke(linePath, with: .color(Color.plexGold.opacity(0.8)), lineWidth: 1.5)

            // Glowing endpoint
            if let last = entries.last {
                let x = size.width
                let y = (1 - last.totalMbps / maxVal) * (size.height - 8) + 4
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 8, y: y - 8, width: 16, height: 16)),
                    with: .color(Color.plexGold.opacity(0.25))
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                    with: .color(Color.plexGold)
                )
            }
        }
    }
}
