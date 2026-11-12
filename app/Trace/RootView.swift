import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var showAsk = false
    @State private var askProjectId: String?

    var body: some View {
        Group {
            if store.preferences.hasCompletedSetup && store.route != .setup {
                NavigationSplitView {
                    sidebar
                } detail: {
                    detail
                }
            } else {
                SetupFlowView()
            }
        }
        .background(TraceTheme.canvas(scheme).ignoresSafeArea())
        .sheet(isPresented: $showAsk) {
            AskTraceView(projectId: askProjectId)
                .environmentObject(store)
                .frame(minWidth: 520, minHeight: 360)
        }
        .onReceive(NotificationCenter.default.publisher(for: .traceOpenAsk)) { _ in
            askProjectId = nil
            showAsk = true
        }
    }

    private var sidebar: some View {
        List {
            Section("Trace") {
                Button {
                    store.route = .home
                    store.refreshEvidence()
                } label: {
                    Label("Home", systemImage: "house")
                }
                .buttonStyle(.plain)
                Button {
                    store.route = .memory(projectId: nil)
                } label: {
                    Label("Memory", systemImage: "books.vertical")
                }
                .buttonStyle(.plain)
                Button {
                    store.route = .setup
                } label: {
                    Label("Setup", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
            }
            Section("Note") {
                Text("Run & Execute are M2. Home never starts a model call.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 190)
    }

    @ViewBuilder
    private var detail: some View {
        switch store.route {
        case .home, .setup:
            HomeView(onAsk: { projectId in
                askProjectId = projectId
                showAsk = true
            })
        case .memory(let projectId):
            MemoryView(projectId: projectId)
        case .decideLater(let id):
            DecideLaterDetailView(itemId: id, onAsk: {
                askProjectId = store.decideLater.first(where: { $0.id == id })?.project_id
                showAsk = true
            })
        }
    }
}
