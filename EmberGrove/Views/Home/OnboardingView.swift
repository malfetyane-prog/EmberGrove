import SwiftUI

/// Chapter 1 as a first-launch experience: a dark, frosty grove, a tiny glow in the ashes, and a name.
@MainActor
struct OnboardingView: View {
    @Environment(GameStore.self) private var store
    @State private var step = 0
    @State private var name = "Ember"
    @FocusState private var nameFocused: Bool

    private var mood: EmberMood {
        switch step {
        case 0: .sleepy
        case 1: .curious
        default: .happy
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.duskDeep, Palette.dusk, Color(hex: 0x4A3768)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Palette.amberGlow.opacity(step == 0 ? 0.15 : 0.45), .clear],
                                             center: .center, startRadius: 5, endRadius: 160))
                        .frame(width: 320, height: 320)
                        .animation(.easeInOut(duration: 1.2), value: step)
                    EmberView(appearance: .starter, mood: mood)
                        .frame(width: 190, height: 190)
                        .scaleEffect(step == 0 ? 0.8 : 1)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: step)
                }

                Group {
                    switch step {
                    case 0:
                        page(title: "The grove has gone cold",
                             body: "The fire went out long ago, and the creatures drifted away. But in the ashes, something is still glowing.")
                    case 1:
                        page(title: "It's waiting for you",
                             body: "When you focus in the real world, it keeps the fire alive. Every minute helps it grow, and brings the grove back to life.")
                    default:
                        VStack(spacing: 14) {
                            Text("What will you call it?")
                                .font(.display(26, weight: .heavy)).foregroundStyle(Palette.cream)
                            TextField("Name", text: $name)
                                .font(.display(22, weight: .bold))
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                                .foregroundStyle(Palette.cream)
                                .focused($nameFocused)
                                .submitLabel(.done)
                                .padding(.horizontal, 40)
                            Text("No streaks to break. No penalties for rest. Just you, your work, and a little friend who's glad you're here.")
                                .font(.subheadline).foregroundStyle(Palette.lavender)
                                .multilineTextAlignment(.center).padding(.horizontal, 30)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .id(step)

                Spacer()

                Button {
                    if step < 2 {
                        withAnimation(.easeInOut(duration: 0.5)) { step += 1 }
                        Haptics.tap()
                    } else {
                        store.rename(name)
                        store.updateSettings { $0.hasOnboarded = true }
                        store.sound.play(.start)
                        Haptics.success()
                    }
                } label: {
                    Text(step == 0 ? "Look closer" : (step == 1 ? "Wake it gently" : "Light the first spark"))
                }
                .buttonStyle(GlowButtonStyle())
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
        .onTapGesture { nameFocused = false }
    }

    private func page(title: String, body: String) -> some View {
        VStack(spacing: 12) {
            Text(title).font(.system(.title, design: .serif, weight: .bold)).foregroundStyle(Palette.cream)
                .multilineTextAlignment(.center)
            Text(body).font(.system(.body, design: .serif)).foregroundStyle(Palette.lavender)
                .multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal, 32)
        }
    }
}
