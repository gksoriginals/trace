import SwiftUI

/// Default Home: Decide-later first, then project insights. Local reads only.
struct HomeView: View {
    @EnvironmentObject private var store: TraceStore
    @Environment(\.colorScheme) private var scheme
    @State private var askText = ""
    @State private var showAsk = false

    var body: some View {
        NavigationSplitView {
            List {
                Section("Trace") {
                    Label("Home", systemImage: "house")
                    Text("Run & Execute come in M2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    decideLaterLane
                    insightsLane
                    if let error = store.loadError {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
                .padding(24)
            }
            .background(TraceTheme.canvas(scheme))
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Re-read local skill logs. Does not call a model.")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAsk = true
                } label: {
                    Label("Ask Trace", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        .sheet(isPresented: $showAsk) {
            AskTraceView(seed: askText)
                .environmentObject(store)
                .frame(minWidth: 480, minHeight: 320)
        }
        .onAppear { store.refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Trace")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(TraceTheme.brand(scheme))
            Text("Local outcomes from your coding-agent skills. Opening Home does not start a model call.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var decideLaterLane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Decide later")
                .font(.system(size: 15, weight: .semibold))
            if store.decideLater.isEmpty {
                Text("No open doubts. Skills will queue items here when a cleanup is unclear.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.decideLater) { item in
                    DecideLaterCard(item: item)
                }
            }
        }
    }

    private var insightsLane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects")
                .font(.system(size: 15, weight: .semibold))
            if store.insights.isEmpty {
                Text("No projects in ~/.trace/index.json yet. Install skills and use them in a coding session, or finish Setup.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.insights) { insight in
                    ProjectInsightCard(insight: insight)
                }
            }
        }
    }
}

struct DecideLaterCard: View {
    let item: DecideLaterItem
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "diamond")
                    .foregroundStyle(TraceTheme.reviewLight)
                Text(item.action)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text(item.status)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text(item.why_doubtful)
                .font(.system(size: 13))
            if let resolve = item.would_resolve {
                Text("Would resolve: \(resolve)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Text(item.project_id)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TraceTheme.surface(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

struct ProjectInsightCard: View {
    let insight: ProjectInsight
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(insight.project.name)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                if insight.openQueueCount > 0 {
                    Text("\(insight.openQueueCount) open")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(TraceTheme.reviewLight)
                }
            }
            if insight.recentEvents.isEmpty {
                Text("No memory events yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(insight.recentEvents) { event in
                    HStack(alignment: .top, spacing: 8) {
                        Text(event.event_type)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(TraceTheme.brand(scheme))
                            .frame(width: 100, alignment: .leading)
                        Text(event.why ?? event.what?.location ?? event.event_id)
                            .font(.system(size: 12))
                            .lineLimit(2)
                    }
                }
            }
            Text(insight.project.memory_log)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TraceTheme.surface(scheme))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
