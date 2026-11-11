import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: TraceStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if store.hasCompletedSetup {
                HomeView()
            } else {
                SetupView(isOnboarding: true)
            }
        }
        .background(TraceTheme.canvas(scheme).ignoresSafeArea())
    }
}
