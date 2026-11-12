import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    var onAsk: (String?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                decideLaterLane
                projectsLane
                if let msg = store.statusMessage {
                    Text(msg).font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .background(TraceTheme.canvas(scheme))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.refreshEvidence()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Re-read local skill files. No model call.")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { onAsk(nil) } label: {
                    Label("Ask Trace", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        .onAppear { store.refreshEvidence() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Trace")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(TraceTheme.brand(scheme))
            Text("Decide later and project insights from local skill evidence.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var decideLaterLane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Decide later")
                .font(.system(size: 15, weight: .semibold))
            if store.decideLater.isEmpty {
                Text("Nothing waiting for a decision.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.decideLater) { item in
                    Button {
                        store.route = .decideLater(item.id)
                    } label: {
                        DecideLaterRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var projectsLane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects")
                .font(.system(size: 15, weight: .semibold))
            if store.insights.isEmpty {
                Text("No projects in ~/.trace/index.json yet. Finish Setup and use skills in Cursor/Codex.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.insights) { insight in
                    InsightCard(insight: insight, onAsk: { onAsk(insight.project.id) })
                }
            }
        }
    }
}

struct DecideLaterRow: View {
    let item: DecideLaterItem
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "diamond")
                    .foregroundStyle(TraceTheme.review(scheme))
                Text(item.action)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(item.status)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text(item.why_doubtful)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Text(item.project_id)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TraceTheme.surface(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct InsightCard: View {
    let insight: ProjectInsight
    var onAsk: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(insight.project.name)
                    .font(.system(size: 13, weight: .medium))
                Text("Skill")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(TraceTheme.elevated(scheme))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Spacer()
                Text(insight.coverageLabel)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if insight.events.isEmpty {
                Text("No memory events yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(insight.events.prefix(4)) { event in
                    HStack(alignment: .top, spacing: 8) {
                        Text(event.event_type)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(TraceTheme.brand(scheme))
                            .frame(width: 110, alignment: .leading)
                        Text(event.why ?? event.what?.location ?? event.event_id)
                            .font(.system(size: 12))
                            .lineLimit(2)
                    }
                }
            }
            HStack {
                if insight.openQueue > 0 {
                    Text("\(insight.openQueue) open in queue")
                        .font(.caption)
                        .foregroundStyle(TraceTheme.review(scheme))
                }
                Spacer()
                Button("Ask", action: onAsk)
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TraceTheme.surface(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
