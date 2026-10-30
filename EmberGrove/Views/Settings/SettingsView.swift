import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { store.settings[keyPath: keyPath] },
                set: { value in store.updateSettings { $0[keyPath: keyPath] = value } })
    }

    private var reminderTime: Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: store.settings.reminderHour, minute: store.settings.reminderMinute, second: 0, of: .now) ?? .now
        }, set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            store.updateSettings {
                $0.reminderHour = c.hour ?? 9
                $0.reminderMinute = c.minute ?? 0
            }
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Focus timer") {
                    Picker("Default mode", selection: binding(\.defaultMode)) {
                        ForEach(FocusMode.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper("Default length: \(store.settings.defaultMinutes) min", value: binding(\.defaultMinutes), in: 5...180, step: 5)
                    Picker("Default category", selection: binding(\.defaultCategory)) {
                        ForEach(FocusCategory.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    Stepper("Daily goal: \(formatMinutes(store.settings.dailyGoalMinutes))", value: binding(\.dailyGoalMinutes), in: 15...480, step: 15)
                    Toggle("Keep screen awake while focusing", isOn: binding(\.keepScreenAwake))
                }

                Section("Sound") {
                    Picker("Ambience", selection: binding(\.ambient)) {
                        ForEach(AmbientSound.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                    HStack {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: binding(\.ambientVolume), in: 0...1)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Ambience volume")
                    Toggle("Sound effects", isOn: binding(\.soundEffects))
                }

                Section {
                    Toggle("Notify when a timer finishes", isOn: binding(\.sessionNotifications))
                    Toggle("Gentle daily reminder", isOn: binding(\.reminderEnabled))
                        .onChange(of: store.settings.reminderEnabled) { _, on in
                            if on { Task { _ = await Notifications.requestAuthorization() } }
                        }
                    if store.settings.reminderEnabled {
                        DatePicker("Remind me at", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Reminders are friendly nudges, never guilt. Missing a day never costs you anything.")
                }

                Section("Accessibility & display") {
                    Toggle("Reduce motion", isOn: binding(\.reduceMotion))
                    Toggle("Haptic feedback", isOn: binding(\.haptics))
                    Picker("Appearance", selection: binding(\.appearance)) {
                        ForEach(AppearancePreference.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section {
                    Toggle("Sync with iCloud", isOn: binding(\.iCloudSync))
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Keeps your grove the same across your devices signed in to the same iCloud account.")
                }

                Section {
                    Button("Start a new grove", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Ember Grove · Made with original art and synthesized sound.")
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Start over?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Erase all progress", role: .destructive) { store.resetProgress() }
            } message: {
                Text("Your character, world and history will be reset. This can't be undone.")
            }
        }
    }
}
