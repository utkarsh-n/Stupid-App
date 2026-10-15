import SwiftUI

/// A floating glass island that morphs open into the day's dose slots.
///
/// This is the only Liquid Glass in the app, and that is deliberate. The HIG is
/// explicit that glass belongs to the navigation layer floating *above* content,
/// never in the content layer — "limit these effects to the most important
/// functional elements." Logging a dose is the most important functional element
/// here, so it gets the glass and the slot cards below do not.
///
/// The morph works because the container's spacing matches the stack's: as each
/// button animates in, its edge crosses the blend threshold and the shapes
/// liquefy apart from the trigger.
struct LogIsland: View {
    let slotNames: [String]
    let filledSlots: Set<Int>
    let onPick: (Int) -> Void

    @State private var isOpen = false
    @Namespace private var glass

    /// Time of day reads instantly at 56pt; three-letter abbreviations do not.
    private static let slotSymbols = ["sunrise.fill", "sun.max.fill", "moon.fill"]

    private var nextOpenSlot: Int? {
        (0..<slotNames.count).first { !filledSlots.contains($0) }
    }

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            HStack(spacing: 18) {
                if isOpen {
                    ForEach(Array(slotNames.enumerated()), id: \.offset) { index, name in
                        slotButton(index: index, name: name)
                    }
                }
                triggerButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private func slotButton(index: Int, name: String) -> some View {
        let done = filledSlots.contains(index)
        return Button {
            close()
            onPick(index)
        } label: {
            Image(systemName: done ? "checkmark" : Self.slotSymbols[safe: index] ?? "circle")
                .font(.system(size: 19, weight: .semibold))
                .symbolColorRenderingMode(.gradient)
                .foregroundStyle(done ? Theme.tideGlow : Theme.ink)
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        // Untinted. The HIG is blunt that tinting everything means nothing stands
        // out — only the trigger is a primary action, so only it gets colour.
        .glassEffect(.regular.interactive(), in: .circle)
        .glassEffectID("slot-\(index)", in: glass)
        .glassEffectTransition(.matchedGeometry)
        .disabled(done)
    }

    private var triggerButton: some View {
        Button {
            if isOpen {
                close()
            } else {
                withAnimation(.smooth(duration: 0.42)) { isOpen = true }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isOpen ? "xmark" : "plus")
                    .font(.system(size: 15, weight: .bold))
                    .contentTransition(.symbolEffect(.replace.offUp))
                if !isOpen {
                    Text("Log dose")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
            }
            .frame(height: 56)
            .padding(.horizontal, isOpen ? 20 : 24)
        }
        .buttonStyle(.plain)
        // Deeper tint than the accent: against a near-black ground a bright tint
        // saturates to a flat fill and loses the material entirely.
        .glassEffect(.regular.tint(Theme.tideDeep.opacity(0.7)).interactive(), in: .capsule)
        .glassEffectID("trigger", in: glass)
        .sensoryFeedback(.impact(weight: .medium), trigger: isOpen)
    }

    private func close() {
        withAnimation(.smooth(duration: 0.42)) { isOpen = false }
    }
}
