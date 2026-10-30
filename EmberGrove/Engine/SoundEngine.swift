import AVFoundation

enum SoundEffect: CaseIterable {
    case start, complete, levelUp, discover, tap
}

/// All audio is synthesized at runtime: no audio files, fully original.
/// Ambient beds are generated sample-by-sample; effects are pre-rendered bell tones.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let synth = AmbientSynth()
    private var source: AVAudioSourceNode?
    private let ambientMixer = AVAudioMixerNode()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var configured = false

    var effectsEnabled = true
    private(set) var ambient: AmbientSound = .none

    private init() {}

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        let node = Self.makeSource(format: format, synth: synth)
        source = node
        engine.attach(node)
        engine.attach(ambientMixer)
        engine.attach(player)
        engine.connect(node, to: ambientMixer, format: format)
        engine.connect(ambientMixer, to: engine.mainMixerNode, format: format)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        for effect in SoundEffect.allCases { buffers[effect] = render(effect) }
    }

    private func ensureRunning(background: Bool) {
        configureIfNeeded()
        let session = AVAudioSession.sharedInstance()
        // .playback keeps ambience going on the lock screen; .ambient respects the silent switch for effects.
        try? session.setCategory(background ? .playback : .ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        if !engine.isRunning { try? engine.start() }
    }

    func setAmbient(_ sound: AmbientSound, volume: Double) {
        ambient = sound
        if sound == .none {
            synth.targetGain = 0
            return
        }
        ensureRunning(background: true)
        ambientMixer.outputVolume = Float(volume)
        synth.kind = sound
        synth.targetGain = 1
    }

    func setVolume(_ volume: Double) {
        ambientMixer.outputVolume = Float(volume)
    }

    func stopAmbient() {
        synth.targetGain = 0
        ambient = .none
    }

    func play(_ effect: SoundEffect) {
        guard effectsEnabled else { return }
        ensureRunning(background: ambient != .none)
        guard let buffer = buffers[effect] else { return }
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts])
        if !player.isPlaying { player.play() }
    }

    /// Built outside the main actor: the render block runs on the real-time audio thread.
    private nonisolated static func makeSource(format: AVAudioFormat, synth: AmbientSynth) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(bufferList)
            for frame in 0..<Int(frameCount) {
                let value = synth.next()
                for buffer in abl {
                    let samples = UnsafeMutableBufferPointer<Float>(buffer)
                    samples[frame] = value
                }
            }
            return noErr
        }
    }

    // MARK: Effects

    private func render(_ effect: SoundEffect) -> AVAudioPCMBuffer? {
        // (frequency, start seconds, length, gain)
        let notes: [(Double, Double, Double, Double)]
        switch effect {
        case .start: notes = [(523.25, 0, 1.2, 0.35), (783.99, 0.12, 1.4, 0.3)]
        case .complete: notes = [(523.25, 0, 1.4, 0.3), (659.25, 0.14, 1.4, 0.3), (783.99, 0.28, 1.6, 0.3), (1046.5, 0.46, 2.0, 0.28)]
        case .levelUp: notes = [(587.33, 0, 1, 0.25), (739.99, 0.09, 1, 0.25), (880, 0.18, 1, 0.25), (1174.66, 0.27, 1.8, 0.3), (1479.98, 0.36, 2.0, 0.2)]
        case .discover: notes = [(987.77, 0, 1.4, 0.25), (1318.51, 0.18, 1.8, 0.25)]
        case .tap: notes = [(880, 0, 0.35, 0.15)]
        }
        let sr = format.sampleRate
        let total = notes.map { $0.1 + $0.2 }.max() ?? 1
        let frames = AVAudioFrameCount(total * sr)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) { data[i] = 0 }
        for (freq, start, length, gain) in notes {
            let s0 = Int(start * sr), n = Int(length * sr)
            for i in 0..<n where s0 + i < Int(frames) {
                let t = Double(i) / sr
                let attack = min(1, t / 0.006)
                let env = attack * exp(-t * 3.2)
                // Bell-like partials
                let v = sin(2 * .pi * freq * t)
                    + 0.45 * sin(2 * .pi * freq * 2.0 * t) * exp(-t * 4)
                    + 0.25 * sin(2 * .pi * freq * 3.01 * t) * exp(-t * 6)
                data[s0 + i] += Float(v * env * gain * 0.5)
            }
        }
        return buffer
    }
}

/// Real-time sample generator for the ambient beds. Runs on the audio thread.
final class AmbientSynth: @unchecked Sendable {
    var kind: AmbientSound = .none
    var targetGain: Float = 0
    private var gain: Float = 0
    private let sampleRate: Float = 44_100

    private var seed: UInt32 = 0x2545F491
    private var brown: Float = 0
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
    private var crackle: Float = 0
    private var hiss: Float = 0
    private var dropEnv: Float = 0, dropPhase: Float = 0, dropFreq: Float = 2000
    private var lfo: Float = 0
    private var wind: Float = 0
    private var chirpLeft = 0, chirpLength = 1, gapLeft = 0, chirpsRemaining = 0
    private var chirpPhase: Float = 0, chirpBase: Float = 3000
    private var untilNextSong: Float = 4

    private func white() -> Float {
        seed ^= seed << 13
        seed ^= seed >> 17
        seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }

    private func unit() -> Float { (white() + 1) * 0.5 }

    func next() -> Float {
        gain += (targetGain - gain) * 0.00008
        if gain < 0.0001 && targetGain == 0 { return 0 }
        let sample: Float
        switch kind {
        case .campfire: sample = campfire()
        case .rain: sample = rain()
        case .breeze: sample = breeze()
        case .none: sample = 0
        }
        return sample * gain
    }

    private func campfire() -> Float {
        let w = white()
        brown = (brown + 0.02 * w) / 1.02
        hiss += 0.15 * (w - hiss)
        if unit() < 10 / sampleRate { crackle = 0.25 + 0.75 * unit() }
        let pop = white() * crackle
        crackle *= 0.992
        return brown * 1.8 + hiss * 0.03 + pop * 0.32
    }

    private func rain() -> Float {
        let w = white()
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        let pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11
        b6 = w * 0.115926
        if unit() < 5 / sampleRate {
            dropEnv = 0.5 + 0.5 * unit()
            dropFreq = 1400 + 1800 * unit()
        }
        dropPhase += 2 * .pi * dropFreq / sampleRate
        if dropPhase > 2 * .pi { dropPhase -= 2 * .pi }
        dropFreq *= 0.99995
        let drop = sin(dropPhase) * dropEnv * 0.06
        dropEnv *= 0.9988
        return pink * 0.45 + drop
    }

    private func breeze() -> Float {
        let w = white()
        lfo += 2 * .pi * 0.07 / sampleRate
        if lfo > 2 * .pi { lfo -= 2 * .pi }
        let cutoff = 0.008 + 0.025 * (0.5 + 0.5 * sin(lfo))
        wind += cutoff * (w - wind)
        var out = wind * 2.2 * (0.55 + 0.45 * sin(lfo * 0.6 + 1))

        // Occasional bird song: a few quick rising chirps
        if chirpsRemaining == 0 {
            untilNextSong -= 1 / sampleRate
            if untilNextSong <= 0 {
                chirpsRemaining = 2 + Int(unit() * 3)
                chirpBase = 2600 + 1200 * unit()
                chirpLength = Int(sampleRate * (0.05 + 0.04 * unit()))
                chirpLeft = chirpLength
                untilNextSong = 5 + 9 * unit()
            }
        } else if chirpLeft > 0 {
            let p = 1 - Float(chirpLeft) / Float(chirpLength)
            chirpPhase += 2 * .pi * (chirpBase + 1500 * p) / sampleRate
            if chirpPhase > 2 * .pi { chirpPhase -= 2 * .pi }
            out += sin(chirpPhase) * sin(.pi * p) * 0.05
            chirpLeft -= 1
            if chirpLeft == 0 { gapLeft = Int(sampleRate * 0.07) }
        } else if gapLeft > 0 {
            gapLeft -= 1
            if gapLeft == 0 {
                chirpsRemaining -= 1
                if chirpsRemaining > 0 { chirpLeft = chirpLength }
            }
        }
        return out
    }
}
