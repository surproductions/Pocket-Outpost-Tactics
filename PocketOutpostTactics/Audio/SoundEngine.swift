import AVFoundation

/// Tiny synthesizer: every sound effect is generated at launch from sine waves and noise, so the
/// game ships with zero audio files and no licensing questions. Uses the ambient session category
/// so the silent switch is respected and the player's own music keeps playing.
final class SoundEngine {
    static let shared = SoundEngine()

    enum Effect: CaseIterable {
        case tap, select, step, hit, heavyHit, defeatFoe, heal, build, upgrade, coin, victory, defeat, turn, error
    }

    var enabled = true
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var started = false
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private init() {}

    func prepare() {
        guard !started else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio is optional; keep the game running silently.
        }
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        engine.mainMixerNode.outputVolume = 0.55
        for effect in Effect.allCases { buffers[effect] = render(effect) }
        do {
            try engine.start()
            players.forEach { $0.play() }
            started = true
        } catch {
            started = false
        }
    }

    func play(_ effect: Effect) {
        guard enabled, started, let buffer = buffers[effect] else { return }
        if !engine.isRunning {
            try? engine.start()
            players.forEach { $0.play() }
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    // MARK: Synthesis

    private struct Note {
        var freq: Double
        var start: Double
        var duration: Double
        var volume: Double = 0.5
        var wave: Wave = .sine
        var slide: Double = 0
    }

    private enum Wave { case sine, square, triangle, noise }

    private func notes(for effect: Effect) -> [Note] {
        switch effect {
        case .tap: return [Note(freq: 880, start: 0, duration: 0.05, volume: 0.25, wave: .triangle)]
        case .select: return [Note(freq: 660, start: 0, duration: 0.06, volume: 0.3, wave: .triangle),
                              Note(freq: 990, start: 0.05, duration: 0.08, volume: 0.25, wave: .triangle)]
        case .step: return [Note(freq: 180, start: 0, duration: 0.05, volume: 0.25, wave: .noise)]
        case .hit: return [Note(freq: 300, start: 0, duration: 0.12, volume: 0.5, wave: .noise),
                           Note(freq: 220, start: 0, duration: 0.12, volume: 0.35, wave: .square, slide: -120)]
        case .heavyHit: return [Note(freq: 200, start: 0, duration: 0.2, volume: 0.6, wave: .noise),
                                Note(freq: 110, start: 0, duration: 0.25, volume: 0.45, wave: .square, slide: -60)]
        case .defeatFoe: return [Note(freq: 520, start: 0, duration: 0.08, volume: 0.3, wave: .square),
                                 Note(freq: 390, start: 0.08, duration: 0.08, volume: 0.3, wave: .square),
                                 Note(freq: 260, start: 0.16, duration: 0.18, volume: 0.3, wave: .square, slide: -80)]
        case .heal: return [Note(freq: 523, start: 0, duration: 0.12, volume: 0.3),
                            Note(freq: 659, start: 0.08, duration: 0.12, volume: 0.3),
                            Note(freq: 784, start: 0.16, duration: 0.2, volume: 0.3)]
        case .build: return [Note(freq: 160, start: 0, duration: 0.06, volume: 0.5, wave: .noise),
                             Note(freq: 160, start: 0.12, duration: 0.06, volume: 0.5, wave: .noise),
                             Note(freq: 160, start: 0.24, duration: 0.06, volume: 0.5, wave: .noise)]
        case .upgrade: return [Note(freq: 392, start: 0, duration: 0.12, volume: 0.35, wave: .triangle),
                               Note(freq: 523, start: 0.1, duration: 0.12, volume: 0.35, wave: .triangle),
                               Note(freq: 659, start: 0.2, duration: 0.12, volume: 0.35, wave: .triangle),
                               Note(freq: 1046, start: 0.3, duration: 0.35, volume: 0.35, wave: .triangle)]
        case .coin: return [Note(freq: 988, start: 0, duration: 0.06, volume: 0.3, wave: .square),
                            Note(freq: 1318, start: 0.06, duration: 0.14, volume: 0.3, wave: .square)]
        case .victory: return [Note(freq: 523, start: 0, duration: 0.15, volume: 0.35, wave: .triangle),
                               Note(freq: 659, start: 0.15, duration: 0.15, volume: 0.35, wave: .triangle),
                               Note(freq: 784, start: 0.3, duration: 0.15, volume: 0.35, wave: .triangle),
                               Note(freq: 1046, start: 0.45, duration: 0.5, volume: 0.4, wave: .triangle),
                               Note(freq: 784, start: 0.45, duration: 0.5, volume: 0.2, wave: .sine)]
        case .defeat: return [Note(freq: 392, start: 0, duration: 0.25, volume: 0.35, wave: .triangle),
                              Note(freq: 330, start: 0.25, duration: 0.25, volume: 0.35, wave: .triangle),
                              Note(freq: 262, start: 0.5, duration: 0.6, volume: 0.35, wave: .triangle, slide: -40)]
        case .turn: return [Note(freq: 440, start: 0, duration: 0.1, volume: 0.25, wave: .triangle),
                            Note(freq: 587, start: 0.1, duration: 0.16, volume: 0.25, wave: .triangle)]
        case .error: return [Note(freq: 160, start: 0, duration: 0.12, volume: 0.3, wave: .square)]
        }
    }

    private func render(_ effect: Effect) -> AVAudioPCMBuffer? {
        let ns = notes(for: effect)
        let length = (ns.map { $0.start + $0.duration }.max() ?? 0.1) + 0.02
        let rate = format.sampleRate
        let frames = AVAudioFrameCount(length * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0..<Int(frames) { data[i] = 0 }
        var noiseSeed: UInt32 = 22_222
        for n in ns {
            let startFrame = Int(n.start * rate)
            let count = Int(n.duration * rate)
            var phase = 0.0
            for i in 0..<count where startFrame + i < Int(frames) {
                let t = Double(i) / rate
                let freq = n.freq + n.slide * (t / n.duration)
                phase += freq / rate
                let s: Double
                switch n.wave {
                case .sine: s = sin(2 * .pi * phase)
                case .square: s = sin(2 * .pi * phase) >= 0 ? 0.6 : -0.6
                case .triangle: s = 2 * abs(2 * (phase - floor(phase + 0.5))) - 1
                case .noise:
                    noiseSeed = noiseSeed &* 1_103_515_245 &+ 12_345
                    s = Double(Int32(bitPattern: noiseSeed)) / Double(Int32.max)
                }
                // Quick attack, exponential-ish release
                let attack = min(1, t / 0.006)
                let release = pow(max(0, 1 - t / n.duration), 1.6)
                data[startFrame + i] += Float(s * n.volume * attack * release)
            }
        }
        for i in 0..<Int(frames) { data[i] = max(-1, min(1, data[i])) }
        return buffer
    }
}
