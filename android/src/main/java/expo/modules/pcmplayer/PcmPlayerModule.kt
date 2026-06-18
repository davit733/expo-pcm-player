package expo.modules.pcmplayer

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Base64
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max

class PcmPlayerModule : Module() {
  private val lock = Any()
  private val executor: ExecutorService = Executors.newSingleThreadExecutor()
  private var audioTrack: AudioTrack? = null
  private var sampleRate = 24_000
  private var channels = 1

  override fun definition() = ModuleDefinition {
    Name("PcmPlayer")

    Function("configure") { sampleRate: Int, channels: Int ->
      configure(sampleRate, channels)
    }

    Function("enqueue") { audio: String ->
      enqueue(audio)
    }

    Function("flush") {
      flush()
    }

    Function("dispose") {
      dispose()
    }

    OnDestroy {
      dispose()
      executor.shutdownNow()
    }
  }

  private fun configure(sampleRate: Int, channels: Int) {
    synchronized(lock) {
      disposeLocked()
      this.sampleRate = sampleRate
      this.channels = if (channels == 2) 2 else 1
      audioTrack = createAudioTrack()
      audioTrack?.play()
    }
  }

  private fun enqueue(audio: String): Double {
    val bytes = Base64.decode(audio, Base64.NO_WRAP)
    val channelCount = channels
    val duration = bytes.size.toDouble() / 2.0 / channelCount.toDouble() / sampleRate.toDouble()

    executor.execute {
      synchronized(lock) {
        ensureConfiguredLocked()
        audioTrack?.write(bytes, 0, bytes.size, AudioTrack.WRITE_BLOCKING)
      }
    }

    return duration
  }

  private fun flush() {
    executor.execute {
      synchronized(lock) {
        audioTrack?.pause()
        audioTrack?.flush()
        audioTrack?.play()
      }
    }
  }

  private fun dispose() {
    synchronized(lock) {
      disposeLocked()
    }
  }

  private fun ensureConfiguredLocked() {
    if (audioTrack == null) {
      audioTrack = createAudioTrack()
      audioTrack?.play()
    }
  }

  private fun disposeLocked() {
    audioTrack?.pause()
    audioTrack?.flush()
    audioTrack?.release()
    audioTrack = null
  }

  private fun createAudioTrack(): AudioTrack {
    val channelMask =
      if (channels == 2) AudioFormat.CHANNEL_OUT_STEREO else AudioFormat.CHANNEL_OUT_MONO
    val minBufferSize = AudioTrack.getMinBufferSize(
      sampleRate,
      channelMask,
      AudioFormat.ENCODING_PCM_16BIT
    )
    val bufferSize = max(minBufferSize, sampleRate * channels * 2 / 2)

    return AudioTrack.Builder()
      .setAudioAttributes(
        AudioAttributes.Builder()
          .setUsage(AudioAttributes.USAGE_MEDIA)
          .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
          .build()
      )
      .setAudioFormat(
        AudioFormat.Builder()
          .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
          .setSampleRate(sampleRate)
          .setChannelMask(channelMask)
          .build()
      )
      .setTransferMode(AudioTrack.MODE_STREAM)
      .setBufferSizeInBytes(bufferSize)
      .build()
  }
}
