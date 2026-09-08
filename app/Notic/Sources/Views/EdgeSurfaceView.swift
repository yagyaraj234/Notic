import NoticCore
import SwiftUI

/// The content of one display's edge panel: the dormant pill or the fanned deck.
struct EdgeSurfaceView: View {
    let workspace: NoticWorkspace
    let display: DisplayID
    let geometry: DisplayGeometry
    let commands: AppCommands

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let state = workspace.deckState(on: display)
        // Both the pill and the deck are centred on the edge, so the pill can
        // sit in the deck's panel while the deck slides away, and the panel
        // shrinks around it afterwards without the pill appearing to move.
        ZStack(alignment: .trailing) {
            if state == .dormant {
                PillView(workspace: workspace, display: display, commands: commands)
                    .transition(.opacity)
            } else {
                // Enters and leaves along the same path: from and to the edge.
                DeckView(workspace: workspace, display: display, geometry: geometry, commands: commands)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .animation(Motion.deckTransition, value: state == .dormant)
    }
}

/// The resting marker at the right edge of the display: one coloured dash per
/// note in the deck, floating directly over the desktop with no backing.
struct PillView: View {
    let workspace: NoticWorkspace
    let display: DisplayID
    let commands: AppCommands

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        let notes = workspace.deckNotes
        Button {
            workspace.revealDeck(on: display)
        } label: {
            VStack(spacing: EdgeLayout.pillDashSpacing) {
                if notes.isEmpty {
                    dash(Color(nsColor: .tertiaryLabelColor))
                } else {
                    ForEach(notes) { note in
                        dash(NotePalette.swatch(for: note.color).paper)
                    }
                }
            }
            .padding(.vertical, EdgeLayout.pillPadding)
            .frame(width: EdgeLayout.pillWidth)
            // Respond on approach, before the fan delay elapses: the stripe
            // eases off the edge in the direction the deck will come from.
            .offset(x: hovering && !reduceMotion ? -2 : 0)
            .animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)
            .frame(width: EdgeLayout.pillHitWidth, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Notic notes")
        .accessibilityHint(notes.isEmpty ? "No active notes. Activate to show the deck." : "\(workspace.activeNotes.count) active notes. Activate to show the deck.")
        .secondaryClickMenu { commands.dockMenu(nil) }
        .accessibilityIdentifier("notic.pill")
    }

    /// A soft shadow and hairline keep the pastel readable over light and
    /// dark wallpaper alike, since nothing sits behind it any more.
    private func dash(_ color: Color) -> some View {
        Capsule(style: .continuous)
            .fill(color)
            .overlay(Capsule(style: .continuous).strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.28), radius: 2.5, x: -0.5, y: 1)
            .frame(width: 6, height: EdgeLayout.pillDashHeight)
    }
}
