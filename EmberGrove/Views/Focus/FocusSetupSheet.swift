import SwiftUI

@MainActor
struct FocusSetupSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var mode: FocusMode = .countdown
    @State private var minutes = 25
    @State private var category: FocusCategory = .studying
    @State private var ambient: AmbientSound = .campfire
    @State private var customMinutes = false

    private let presets = [15, 25, 45, 60]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .bottom, spacing: 12) {
                        EmberView(appearance: store.state.appearance, mood: .curious)
                            .frame(width: 84, height: 84)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("What are we focusing on?").font(.display(22)).foregroundStyle(Theme.ink)
                            Text("\(store.state.emberName) will keep the fire going.").font(.subheadline).foregroundStyle(Theme.inkSoft)
                        }
                    }

                    section("Mode") {
                        Picker("Mode", selection: $mode) {
                            ForEach(FocusMode.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if mode == .countdown {
                        section("Length") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    ForEach(presets, id: \.self) { p in
                                        Button { minutes = p; customMinutes = false; Haptics.selection() } label: {
                                            Chip(title: "\(p)m", selected: !customMinutes && minutes == p)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    Button { customMinutes = true; Haptics.selection() } label: {
                                        Chip(title: "Custom", selected: customMinutes)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if customMinutes {
                                    Stepper(value: $minutes, in: 5...180, step: 5) {
                                        Text("\(minutes) minutes").font(.label).foregroundStyle(Theme.ink)
                                    }
                                    .padding(12)
                                    .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                    } else {
                        Text("The stopwatch counts up until you finish. Every minute counts.")
                            .font(.subheadline).foregroundStyle(Theme.inkSoft)
                    }

                    section("Category") {
                        FlowLayout(spacing: 8) {
                            ForEach(FocusCategory.allCases) { c in
                                Button { category = c; Haptics.selection() } label: {
                                    Chip(title: c.title, symbol: c.symbol, selected: category == c, tint: Color(hex: c.hex))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    section("Ambience") {
                        FlowLayout(spacing: 8) {
                            ForEach(AmbientSound.allCases) { a in
                                Button { ambient = a; Haptics.selection() } label: {
                                    Chip(title: a.title, symbol: a.symbol, selected: ambient == a)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(Theme.gutter)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                Button {
                    if store.settings.ambient != ambient { store.updateSettings { $0.ambient = ambient } }
                    let chosen = (mode, minutes, category)
                    dismiss()
                    // Start after the sheet is gone so the focus cover presents cleanly.
                    after(0.35) {
                        store.startSession(mode: chosen.0, minutes: chosen.1, category: chosen.2)
                    }
                } label: {
                    Label(mode == .countdown ? "Focus for \(minutes) minutes" : "Start stopwatch", systemImage: "flame.fill")
                }
                .buttonStyle(GlowButtonStyle())
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 10)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .onAppear {
            let s = store.settings
            mode = s.defaultMode
            minutes = s.defaultMinutes
            category = s.defaultCategory
            ambient = s.ambient
            customMinutes = !presets.contains(s.defaultMinutes)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.inkSoft)
            content()
        }
    }
}

/// Wraps chips onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
