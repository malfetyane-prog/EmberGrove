import SwiftUI

/// The calm, full-screen focus scene: night in the grove, Ember tending the fire, a big readable timer.
@MainActor
struct FocusView: View {
    @Environment(GameStore.self) private var store
    @State private var confirmFinish = false
    @State private var confirmTooShort = false

    var body: some View {
        if let session = store.activeSession {
            content(session)
        } else {
            Color.black.ignoresSafeArea()
        }
    }

    private func content(_ session: ActiveSession) -> some View {
        GeometryReader { geo in
            let span: Double = GroveRenderer.height * Double(geo.size.width) / Double(max(1, geo.size.height))
            let viewport: ClosedRange<Double> = (295 - span / 2)...(295 + span / 2)
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                let now = tl.date
                let elapsed = session.elapsed(at: now)
                ZStack {
                    GroveStage(snapshot: GroveSnapshot(store.state), appearance: store.state.appearance,
                               mood: session.isPaused ? .sleepy : .focused, phase: .night,
                               viewport: viewport, emberX: 322,
                               hearthBoost: session.progress(at: now) ?? min(1, elapsed / 3600),
                               emberSize: 92)
                        .frame(width: geo.size.width, height: geo.size.height)

                    LinearGradient(colors: [Palette.duskDeep.opacity(0.85), Palette.duskDeep.opacity(0.35), .clear],
                                   startPoint: .top, endPoint: .center)

                    VStack(spacing: 0) {
                        topBar(session)
                        Spacer().frame(height: geo.size.height * 0.06)
                        timerBlock(session, elapsed: elapsed, now: now)
                        Spacer()
                        controls(session, elapsed: elapsed)
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, geo.safeAreaInsets.top + 12)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 18)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear { UIApplication.shared.isIdleTimerDisabled = store.settings.keepScreenAwake }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .confirmationDialog("Finish this session?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish and collect rewards") { store.finish() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Every minute you've focused is kept. Ending early is always okay.")
        }
        .alert("Just getting started", isPresented: $confirmTooShort) {
            Button("Keep going", role: .cancel) {}
            Button("End without saving", role: .destructive) { store.discard() }
        } message: {
            Text("Sessions shorter than a minute aren't saved.")
        }
    }

    private func topBar(_ session: ActiveSession) -> some View {
        HStack {
            Label(session.category.title, systemImage: session.category.symbol)
                .font(.label)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.white.opacity(0.12), in: Capsule())
            Spacer()
            Menu {
                Picker("Ambience", selection: Binding(get: { store.settings.ambient }, set: { store.setAmbient($0) })) {
                    ForEach(AmbientSound.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
            } label: {
                Image(systemName: store.settings.ambient.symbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("Ambient sound: \(store.settings.ambient.title)")
        }
        .foregroundStyle(Palette.cream)
    }

    private func timerBlock(_ session: ActiveSession, elapsed: TimeInterval, now: Date) -> some View {
        let display = session.remaining(at: now) ?? elapsed
        return VStack(spacing: 10) {
            Text(formatDuration(display))
                .font(.system(size: 84, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.cream)
                .shadow(color: Palette.amber.opacity(0.35), radius: 18)
                .contentTransition(.numericText(countsDown: session.mode == .countdown))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityLabel(session.mode == .countdown ? "\(Int(display / 60)) minutes remaining" : "\(Int(display / 60)) minutes focused")

            if let progress = session.progress(at: now) {
                GlowBar(value: progress, height: 6)
                    .frame(maxWidth: 220)
            }

            Text(session.isPaused ? "\(store.state.emberName) is dozing while you rest." : encouragement(elapsed))
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(Palette.lavender)
                .multilineTextAlignment(.center)
                .animation(.easeInOut, value: Int(elapsed / 240))
        }
    }

    private func controls(_ session: ActiveSession, elapsed: TimeInterval) -> some View {
        HStack(spacing: 28) {
            Spacer()
            Button {
                session.isPaused ? store.resume() : store.pause()
            } label: {
                Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 78, height: 78)
                    .background(Circle().fill(LinearGradient(colors: [Palette.amberGlow, Palette.amber], startPoint: .top, endPoint: .bottom)))
                    .shadow(color: Palette.amber.opacity(0.5), radius: 16)
            }
            .accessibilityLabel(session.isPaused ? "Resume" : "Pause")

            Button {
                if elapsed < 60 { confirmTooShort = true }
                else if session.mode == .countdown { confirmFinish = true }
                else { store.finish() }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.cream)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(.white.opacity(0.14)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1))
            }
            .accessibilityLabel("Finish session")
            Spacer()
        }
    }

    private func encouragement(_ elapsed: TimeInterval) -> String {
        let name = store.state.emberName
        let lines = [
            "\(name) is tending the fire.",
            "The grove is quiet. Just you and the work.",
            "\(name) added another twig to the fire.",
            "Somewhere in the grove, a firefly woke up.",
            "The frost is thinning, just a little.",
            "\(name) is humming very softly.",
            "The stars are out. The fire is warm.",
        ]
        return lines[Int(elapsed / 240) % lines.count]
    }
}
