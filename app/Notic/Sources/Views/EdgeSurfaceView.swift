import NoticCore
import SwiftUI

/// The content of one display's edge panel: the dormant pill or the fanned deck.
struct EdgeSurfaceView: View {
    let workspace: NoticWorkspace
    let display: DisplayID
    let geometry: DisplayGeometry
    let commands: AppCommands

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The state the surface is drawn in, which trails the workspace's state
    /// by exactly one explicit transaction. `nil` until the first update, so
    /// the surface's first appearance is not animated.
    @State private var fanned: Bool?

    var body: some View {
        let frame = geometry.layout.deckFrame(
            noteCount: workspace.deckNotes.count, hasOverflow: workspace.overflowCount > 0,
            footerRows: footerRows
        )
        let bottom = geometry.layout.edge == .bottom
        surface
            .frame(width: bottom ? frame.height : frame.width, height: bottom ? frame.width : frame.height)
            .scaleEffect(x: geometry.layout.edge == .left ? -1 : 1, y: 1)
            .rotationEffect(.degrees(bottom ? 90 : 0))
            .frame(width: frame.width, height: frame.height)
    }

    private var footerRows: Int {
        var rows = workspace.pendingDeletions.isEmpty ? 0 : 1
        if case .failed = workspace.saveState { rows += 1 }
        return rows
    }

    @ViewBuilder private var surface: some View {
        let target = workspace.deckState(on: display) != .dormant
        let fanned = self.fanned ?? target
        // The pill and the deck are both mounted, both centred on the edge,
        // and the deck sits over the pill. Swapping one for the other left a
        // frame with nothing on the edge at all — the pill was gone before the
        // deck had been built. Now the deck covers the pill on the way out and
        // uncovers it on the way back, and a fan interrupted halfway retargets
        // from where it is rather than restarting.
        ZStack(alignment: .trailing) {
            PillView(workspace: workspace, display: display, commands: commands,
                     hitWidth: geometry.layout.activationDepth)
                .opacity(fanned ? 0 : 1)
                .inert(fanned)

            // Leaves along the path it arrived by: from and to the edge. It
            // stays opaque throughout so that it always covers the pill; only
            // reduced motion trades the travel for a fade.
            DeckView(workspace: workspace, display: display, geometry: geometry, commands: commands)
                .offset(x: fanned || reduceMotion ? 0 : EdgeLayout.deckWidth)
                .opacity(!reduceMotion || fanned ? 1 : 0)
                .inert(!fanned)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        // One explicit transaction for both surfaces. Implicit animation was
        // not reliably producing one here: the deck slid out but folded back
        // in a single frame.
        .onChange(of: target, initial: true) { _, target in
            guard self.fanned != target else { return }
            guard self.fanned != nil else {
                self.fanned = target
                return
            }
            withAnimation(Motion.deck(fanning: target, reduceMotion: reduceMotion)) {
                self.fanned = target
            }
        }
    }
}

private extension View {
    /// Takes a surface out of play without unmounting it. Both edge surfaces
    /// stay in the tree so neither has to be built mid-transition, so the one
    /// that is faded out must not answer a click, a hover, or VoiceOver.
    func inert(_ inert: Bool) -> some View {
        allowsHitTesting(!inert).accessibilityHidden(inert)
    }
}

/// The resting marker at the right edge of the display: one coloured dash per
/// note in the deck, sharing a translucent black backing.
struct PillView: View {
    let workspace: NoticWorkspace
    let display: DisplayID
    let commands: AppCommands
    let hitWidth: CGFloat

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
            .background(.black.opacity(0.5), in: UnevenRoundedRectangle(
                topLeadingRadius: EdgeLayout.pillWidth / 2,
                bottomLeadingRadius: EdgeLayout.pillWidth / 2,
                bottomTrailingRadius: 0, topTrailingRadius: 0
            ))
            // Respond on approach, before the fan delay elapses: the stripe
            // eases off the edge in the direction the deck will come from.
            .offset(x: hovering && !reduceMotion ? -2 : 0)
            .animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)
            .frame(width: EdgeLayout.pillHitWidth, alignment: .trailing)
            .frame(width: hitWidth, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Notic notes")
        .accessibilityHint(notes.isEmpty ? "No active notes. Activate to show the deck." : "\(workspace.activeNotes.count) active notes. Activate to show the deck.")
        .secondaryClickMenu { commands.dockMenu(nil) }
        .accessibilityIdentifier("notic.pill")
    }

    /// A soft shadow and hairline define each pastel dash.
    private func dash(_ color: Color) -> some View {
        Capsule(style: .continuous)
            .fill(color)
            .overlay(Capsule(style: .continuous).strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.28), radius: 2.5, x: -0.5, y: 1)
            .frame(width: 6, height: EdgeLayout.pillDashHeight)
    }
}
