import SwiftUI

struct SystemView: View {
    @EnvironmentObject var data: PlexDataManager

    private var cpu: Double { data.resources?.hostCpu ?? 0 }
    private var ram: Double { data.resources?.hostRam ?? 0 }
    private var cpuHist: [Double] { data.resources?.cpuHistory ?? [] }
    private var ramHist: [Double] { data.resources?.ramHistory ?? [] }

    private var healthStatus: (String, Color) {
        if cpu > 90 || ram > 90 { return ("Critical", .plexRed) }
        if cpu > 70 || ram > 80 { return ("Elevated", .plexAmber) }
        return ("Healthy", .plexGreen)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.plexGold)
                Text("System")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.wText)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(healthStatus.1).frame(width: 6, height: 6)
                        .shadow(color: healthStatus.1.opacity(0.5), radius: 3)
                    Text(healthStatus.0)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.wTextDim)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Rectangle().fill(Color.wSeparator).frame(height: 1).padding(.horizontal, 16)

            HStack(spacing: 24) {
                ArcGaugeView(value: cpu, color: .plexCyan, label: "CPU", detail: data.serverName)
                ArcGaugeView(value: ram, color: .plexPurple, label: "RAM", detail: "Host")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Rectangle().fill(Color.wSeparator).frame(height: 1).padding(.horizontal, 16)

            HStack(spacing: 14) {
                SparklineColumn(label: "CPU · 60s", value: cpu, color: .plexCyan, data: cpuHist)
                SparklineColumn(label: "RAM · 60s", value: ram, color: .plexPurple, data: ramHist)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 340)
        .widgetBackground()
    }
}

// MARK: - Arc Gauge
struct ArcGaugeView: View {
    let value: Double
    let color: Color
    let label: String
    let detail: String

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                ArcShape()
                    .stroke(Color.wTrack, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .frame(width: 76, height: 42)
                ArcShape()
                    .trim(from: 0, to: min(value / 100, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .frame(width: 76, height: 42)
                    .shadow(color: color.opacity(0.35), radius: 4)
                    .animation(.easeOut(duration: 1.0), value: value)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(Int(value))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.wText)
                        .contentTransition(.numericText())
                    Text("%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.wTextDim)
                }
                .offset(y: 6)
            }
            .frame(height: 46)

            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.wTextMid)
            Text(detail)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(Color.wTextFaint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height * 2) / 2
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        return path
    }
}

// MARK: - Sparkline
struct SparklineColumn: View {
    let label: String
    let value: Double
    let color: Color
    let data: [Double]

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(Color.wTextDim)
                Spacer()
                Text("\(Int(value))%")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }

            if data.count >= 2 {
                Canvas { context, size in
                    var linePath = Path()
                    for (i, val) in data.enumerated() {
                        let x = CGFloat(i) / CGFloat(data.count - 1) * size.width
                        let y = size.height - (val / 100) * (size.height - 4) - 2
                        if i == 0 { linePath.move(to: CGPoint(x: x, y: y)) }
                        else { linePath.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    var fillPath = linePath
                    fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
                    fillPath.addLine(to: CGPoint(x: 0, y: size.height))
                    fillPath.closeSubpath()

                    context.fill(fillPath, with: .linearGradient(
                        Gradient(colors: [color.opacity(0.25), color.opacity(0)]),
                        startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
                    ))
                    context.stroke(linePath, with: .color(color), lineWidth: 1.5)
                }
                .frame(height: 26)
            } else {
                Rectangle().fill(Color.wCardBg).frame(height: 26)
            }
        }
    }
}
