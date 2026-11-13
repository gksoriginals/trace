import SwiftUI

/// S5 Home — project insight tiles. Decide later lives in the top-nav bell.
struct HomeView: View {
    @ObservedObject var model: AppModel

    private var store: TraceStore { model.store }
    private var supervisor: SessionSupervisor { model.supervisor }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TraceSpace.lg) {
                agentBanner
                if let error = store.loadError {
                    TraceStatusBanner(
                        kind: .error,
                        title: "Could not load local files",
                        detail: error
                    )
                }
                insightsLane
            }
            .tracePageColumn()
        }
        .background(TraceColor.canvas)
    }

    @ViewBuilder
    private var agentBanner: some View {
        if supervisor.isBusy {
            TraceStatusBanner(
                kind: .working,
                title: supervisor.pendingPermission != nil
                    ? "Needs your answer"
                    : "Running\(model.activeRunLabel.map { " · \($0)" } ?? "")…",
                detail: supervisor.lastMessage ?? "Opening agent session…",
                primaryTitle: "Stop",
                primaryAction: { Task { await supervisor.cancel() } },
                secondaryTitle: supervisor.pendingPermission != nil ? "Allow once" : nil,
                secondaryAction: supervisor.pendingPermission != nil
                    ? { Task { await supervisor.replyToPermission(allow: true) } }
                    : nil
            )
        } else if supervisor.isFailed || supervisor.isCancelled {
            TraceStatusBanner(
                kind: .error,
                title: supervisor.isCancelled
                    ? "Run cancelled\(model.activeRunLabel.map { " · \($0)" } ?? "")"
                    : "Run failed\(model.activeRunLabel.map { " · \($0)" } ?? "")",
                detail: model.lastRunOutcome
                    ?? supervisor.lastMessage
                    ?? (supervisor.isCancelled ? "Stopped." : "Unknown error"),
                primaryTitle: "Run again",
                primaryAction: {
                    Task {
                        if let id = model.activeRunProjectId,
                           let project = store.projects.first(where: { $0.id == id }) {
                            await model.runInPlace(.project(project))
                        } else {
                            await model.runInPlace(.allPermitted)
                        }
                    }
                },
                secondaryTitle: "Dismiss",
                secondaryAction: { model.clearRunBanner() }
            )
        } else if supervisor.isCompleted || model.lastRunOutcome != nil {
            TraceStatusBanner(
                kind: .info,
                title: "Run finished\(model.activeRunLabel.map { " · \($0)" } ?? "")",
                detail: model.lastRunOutcome
                    ?? "Agent finished. \(store.decideLater.count) open decide-later item\(store.decideLater.count == 1 ? "" : "s").",
                primaryTitle: store.decideLater.isEmpty ? "Run again" : "Review items",
                primaryAction: {
                    if store.decideLater.isEmpty {
                        Task { await model.runInPlace(.allPermitted) }
                    } else {
                        model.destination = .decideLaterQueue
                    }
                },
                secondaryTitle: "Dismiss",
                secondaryAction: { model.clearRunBanner() }
            )
        }
    }

    private var insightsLane: some View {
        VStack(alignment: .leading, spacing: TraceSpace.sm) {
            TraceSectionLabel(title: "Projects")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: TraceSpace.md)],
                alignment: .leading,
                spacing: TraceSpace.md
            ) {
                AddProjectCard {
                    model.addProjectFolders()
                }
                ForEach(store.insights) { insight in
                    ProjectInsightCard(model: model, insight: insight)
                }
            }
        }
    }
}

/// Empty tile with a large plus — primary way to add project folders.
private struct AddProjectCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: TraceSpace.sm) {
                Image(systemName: TraceSymbol.addFolder)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(TraceColor.brand)
                Text("Add folder")
                    .font(TraceType.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 118)
            .background(
                RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                    .strokeBorder(TraceColor.brand.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .background(
                        RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                            .fill(TraceColor.surface.opacity(0.55))
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Add project folder")
        .accessibilityLabel("Add folder")
    }
}

/// Compact project tile for the Home grid — dense so many projects fit on screen.
private struct ProjectInsightCard: View {
    @ObservedObject var model: AppModel
    let insight: ProjectInsight

    private var store: TraceStore { model.store }
    private var isThisRunning: Bool {
        model.supervisor.isBusy && model.activeRunProjectId == insight.project.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TraceSpace.sm) {
            Button {
                model.destination = .memory(insight.project.id)
            } label: {
                VStack(alignment: .leading, spacing: TraceSpace.sm) {
                    HStack(alignment: .center, spacing: TraceSpace.sm) {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(StorageCategory.caches.accent)
                            .frame(width: 3, height: 16)
                        Text(insight.project.displayName)
                            .font(TraceType.bodyMedium)
                            .foregroundStyle(TraceColor.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if insight.openQueueCount > 0 {
                            Text("\(insight.openQueueCount)")
                                .font(TraceType.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(TraceColor.review))
                                .accessibilityLabel("\(insight.openQueueCount) decide later")
                        }
                    }

                    if let roots = insight.project.roots, let first = roots.first {
                        Text(Self.shortPath(first))
                            .font(TraceType.path)
                            .foregroundStyle(TraceColor.textSecondary)
                            .lineLimit(1)
                            .help(first)
                    }

                    insightBody
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open memory for \(insight.project.displayName)")

            if isThisRunning {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text(model.supervisor.lastMessage ?? "Running…")
                        .font(TraceType.caption)
                        .foregroundStyle(TraceColor.review)
                        .lineLimit(1)
                }
            }

            HStack {
                Spacer(minLength: 0)
                Button {
                    Task { await model.runInPlace(.project(insight.project)) }
                } label: {
                    if isThisRunning {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: TraceSymbol.run)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
                .controlSize(.small)
                .disabled(model.supervisor.isBusy)
                .help("Run \(insight.project.displayName)")
                .accessibilityLabel("Run \(insight.project.displayName)")
            }
        }
        .padding(TraceSpace.md)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                .fill(TraceColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                .stroke(isThisRunning ? TraceColor.brand : TraceColor.line.opacity(0.35), lineWidth: isThisRunning ? 1.5 : 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Project \(insight.project.displayName)")
    }

    @ViewBuilder
    private var insightBody: some View {
        // Prefer last-run receipt / insights; fall back to skill memory; never “No memory yet”.
        let body = store.insightBodies[insight.project.id] ?? ""
        if !body.isEmpty {
            Text(cardSummary(from: body))
                .font(TraceType.meta)
                .foregroundStyle(TraceColor.textSecondary)
                .lineLimit(2)
        } else if let run = store.runs(for: insight.project.id).first {
            Text(run.summary)
                .font(TraceType.meta)
                .foregroundStyle(TraceColor.textSecondary)
                .lineLimit(2)
        } else if let event = insight.recentEvents.first {
            Text(event.why ?? event.what?.location ?? event.event_type ?? "Recent activity")
                .font(TraceType.meta)
                .foregroundStyle(TraceColor.textSecondary)
                .lineLimit(2)
        } else {
            Text("Open for insights, history, and Ask — or Run.")
                .font(TraceType.meta)
                .foregroundStyle(TraceColor.textSecondary)
                .lineLimit(2)
        }
    }

    private func cardSummary(from insights: String) -> String {
        let lines = insights
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("- **When") }
        if let summary = lines.first(where: { $0.hasPrefix("- **Summary:**") }) {
            return summary.replacingOccurrences(of: "- **Summary:**", with: "").trimmingCharacters(in: .whitespaces)
        }
        return lines.first { !$0.hasPrefix("-") } ?? lines.first ?? insights
    }

    private static func shortPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let tail = url.lastPathComponent
        let parent = url.deletingLastPathComponent().lastPathComponent
        if parent.isEmpty { return tail }
        return "…/\(parent)/\(tail)"
    }
}
