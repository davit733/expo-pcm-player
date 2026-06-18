import AVFoundation
import ExpoModulesCore

public class PcmPlayerModule: Module {
  private let player = PcmOutputPlayer()

  public func definition() -> ModuleDefinition {
    Name("PcmPlayer")

    Function("configure") { (sampleRate: Double, channels: Int) in
      try self.player.configure(sampleRate: sampleRate, channels: channels)
    }

    Function("enqueue") { (audio: String) -> Double in
      try self.player.enqueue(base64: audio)
    }

    Function("flush") {
      self.player.flush()
    }

    Function("dispose") {
      self.player.dispose()
    }
  }
}

final class PcmOutputPlayer {
  private let queue = DispatchQueue(label: "io.github.davit733.expo-pcm-player")
  private var engine: AVAudioEngine?
  private var playerNode: AVAudioPlayerNode?
  private var format: AVAudioFormat?
  private var sampleRate: Double = 24_000
  private var channels: AVAudioChannelCount = 1

  func configure(sampleRate: Double, channels: Int) throws {
    try queue.sync {
      try configureLocked(sampleRate: sampleRate, channels: channels)
    }
  }

  func enqueue(base64: String) throws -> Double {
    try queue.sync {
      try ensureConfiguredLocked()

      guard let data = Data(base64Encoded: base64), data.count >= 2 else {
        throw PcmPlayerError.invalidAudioChunk
      }

      guard let format else {
        throw PcmPlayerError.notConfigured
      }

      let channelCount = Int(channels)
      let frameCount = data.count / MemoryLayout<Int16>.size / channelCount
      guard frameCount > 0 else {
        return 0
      }

      guard let buffer = AVAudioPCMBuffer(
        pcmFormat: format,
        frameCapacity: AVAudioFrameCount(frameCount)
      ) else {
        throw PcmPlayerError.couldNotCreateBuffer
      }

      buffer.frameLength = AVAudioFrameCount(frameCount)

      guard let channelData = buffer.floatChannelData else {
        throw PcmPlayerError.couldNotCreateBuffer
      }

      for frame in 0..<frameCount {
        for channel in 0..<channelCount {
          let sampleIndex = (frame * channelCount) + channel
          let byteIndex = sampleIndex * MemoryLayout<Int16>.size
          let low = UInt16(data[byteIndex])
          let high = UInt16(data[byteIndex + 1]) << 8
          let sample = Int16(bitPattern: low | high)
          channelData[channel][frame] = Float(sample) / 32_768.0
        }
      }

      if engine?.isRunning != true {
        try engine?.start()
      }

      if playerNode?.isPlaying != true {
        playerNode?.play()
      }

      playerNode?.scheduleBuffer(buffer, completionHandler: nil)

      return Double(frameCount) / sampleRate
    }
  }

  func flush() {
    queue.sync {
      playerNode?.stop()
      playerNode?.play()
    }
  }

  func dispose() {
    queue.sync {
      disposeLocked()
    }
  }

  private func ensureConfiguredLocked() throws {
    if engine == nil || playerNode == nil || format == nil {
      try configureLocked(sampleRate: sampleRate, channels: Int(channels))
    }
  }

  private func configureLocked(sampleRate: Double, channels: Int) throws {
    disposeLocked()

    self.sampleRate = sampleRate
    self.channels = AVAudioChannelCount(max(1, min(channels, 2)))

    guard let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: sampleRate,
      channels: self.channels,
      interleaved: false
    ) else {
      throw PcmPlayerError.couldNotCreateFormat
    }

    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()

    engine.attach(playerNode)
    engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    try engine.start()
    playerNode.play()

    self.engine = engine
    self.playerNode = playerNode
    self.format = format
  }

  private func disposeLocked() {
    playerNode?.stop()
    engine?.stop()

    if let playerNode, let engine {
      engine.detach(playerNode)
    }

    playerNode = nil
    engine = nil
    format = nil
  }
}

enum PcmPlayerError: LocalizedError {
  case invalidAudioChunk
  case notConfigured
  case couldNotCreateFormat
  case couldNotCreateBuffer

  var errorDescription: String? {
    switch self {
    case .invalidAudioChunk:
      return "Invalid PCM audio chunk."
    case .notConfigured:
      return "PCM player is not configured."
    case .couldNotCreateFormat:
      return "Could not create PCM audio format."
    case .couldNotCreateBuffer:
      return "Could not create PCM audio buffer."
    }
  }
}
