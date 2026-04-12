import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Attributes

struct MeridianLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var connectedTransports: [String]
        var lastBeaconTimestamp: Date?
        var beaconingActive: Bool
        var serviceStateLabel: String
    }
    var appName: String
}

// MARK: - Lock Screen / Banner view

struct MeridianLockScreenView: View {
    let context: ActivityViewContext<MeridianLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(connectedColor)
                Text("Meridian APRS")
                    .font(.headline)
                Spacer()
                Text(context.state.serviceStateLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(transportLabel)
                .font(.subheadline)
            if context.state.beaconingActive, let ts = context.state.lastBeaconTimestamp {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.yellow)
                    Text("Last beacon: \(ts, style: .relative) ago")
                        .font(.caption)
                }
            }
        }
        .padding()
        .activityBackgroundTint(Color(.systemBackground))
    }

    var connectedColor: Color {
        context.state.connectedTransports.isEmpty ? .secondary : .green
    }

    var transportLabel: String {
        context.state.connectedTransports.isEmpty
            ? "No connections"
            : "Connected: \(context.state.connectedTransports.joined(separator: " · "))"
    }
}

// MARK: - Live Activity Widget

struct MeridianLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeridianLiveActivityAttributes.self) { context in
            MeridianLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.green)
                        Text("Meridian")
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.beaconingActive {
                        Image(systemName: "location.fill")
                            .foregroundColor(.yellow)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.connectedTransports.isEmpty
                             ? "No connections"
                             : "Connected: \(context.state.connectedTransports.joined(separator: " · "))")
                            .font(.caption)
                        if context.state.beaconingActive, let ts = context.state.lastBeaconTimestamp {
                            Text("Last beacon: \(ts, style: .relative) ago")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        } else if !context.state.beaconingActive {
                            Text("Beaconing off")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(context.state.connectedTransports.isEmpty ? .secondary : .green)
            } compactTrailing: {
                if context.state.beaconingActive, let ts = context.state.lastBeaconTimestamp {
                    Text(ts, style: .relative)
                        .font(.caption2)
                        .monospacedDigit()
                } else {
                    Text("—")
                        .font(.caption2)
                }
            } minimal: {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(context.state.connectedTransports.isEmpty ? .secondary : .green)
            }
            .widgetURL(URL(string: "meridianaprs://"))
            .keylineTint(.green)
        }
    }
}
