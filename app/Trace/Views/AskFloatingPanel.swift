import SwiftUI

/// Corner mini-chat for Ask Trace — composer open, floats over the current surface.
struct AskFloatingPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            AskTraceView(
                model: model,
                initialProjectId: model.askProjectId,
                initialItemId: model.askItemId,
                compact: true,
                onClose: { model.closeAskPanel() }
            )
        }
        .frame(width: 380, height: 520)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TraceColor.surface)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TraceColor.line.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ask Trace")
    }
}
