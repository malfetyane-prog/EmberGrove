import Foundation

/// Saves the game as JSON in the shared App Group container (so the widget could read it too),
/// with optional iCloud key-value sync.
enum Persistence {
    private static var fileURL: URL {
        AppGroup.containerURL.appendingPathComponent("ember-grove-state.json")
    }

    static func load() -> GameState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(GameState.self, from: data)
    }

    static func save(_ state: GameState) {
        do {
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Save failed: \(error)")
        }
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()
}

/// Last-writer-wins sync through iCloud key-value storage. The payload is compressed
/// so years of session history fit comfortably inside the 1 MB limit.
enum CloudSync {
    private static let key = "ember.grove.state"
    private static var store: NSUbiquitousKeyValueStore { .default }

    static func push(_ state: GameState) {
        var shared = state
        shared.activeSession = nil
        guard let raw = try? Persistence.encoder.encode(shared),
              let packed = try? (raw as NSData).compressed(using: .lzfse) as Data else { return }
        store.set(packed, forKey: key)
        store.synchronize()
    }

    static func pull() -> GameState? {
        guard let packed = store.data(forKey: key),
              let raw = try? (packed as NSData).decompressed(using: .lzfse) as Data else { return nil }
        return try? Persistence.decoder.decode(GameState.self, from: raw)
    }

    static func observe(_ handler: @escaping () -> Void) -> NSObjectProtocol {
        store.synchronize()
        return NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store, queue: .main) { _ in handler() }
    }
}
