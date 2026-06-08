package com.example.rgb_ble_controller

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.ln
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private var audioHandler: AudioLevelStreamHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioHandler = AudioLevelStreamHandler()
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rgb_ble_controller/audio_level"
        ).setStreamHandler(audioHandler)
    }

    override fun onDestroy() {
        audioHandler?.stop()
        super.onDestroy()
    }
}

private class AudioLevelStreamHandler : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var activeFlag: AtomicBoolean? = null
    private var worker: Thread? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stop()
        val flag = AtomicBoolean(true)
        activeFlag = flag
        worker = Thread({ recordLoop(events, flag) }, "audio-level-meter").also {
            it.isDaemon = true
            it.start()
        }
    }

    override fun onCancel(arguments: Any?) {
        stop()
    }

    fun stop() {
        activeFlag?.set(false)
        activeFlag = null
        val thread = worker
        worker = null
        thread?.interrupt()
        if (thread != null && thread != Thread.currentThread()) {
            try {
                thread.join(200)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }
    }

    private fun recordLoop(events: EventChannel.EventSink, running: AtomicBoolean) {
        val sampleRate = 16000
        val minSize = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minSize <= 0) {
            postError(events, "audio_unavailable", "AudioRecord buffer is unavailable")
            return
        }

        val bufferSize = minSize.coerceAtLeast(sampleRate / 10)
        val buffer = ShortArray(bufferSize / 2)
        val recorder = try {
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )
        } catch (e: SecurityException) {
            postError(events, "audio_permission", e.message ?: "Microphone permission denied")
            return
        } catch (e: IllegalArgumentException) {
            postError(events, "audio_unavailable", e.message ?: "AudioRecord init failed")
            return
        }

        try {
            recorder.startRecording()
            while (running.get()) {
                val read = recorder.read(buffer, 0, buffer.size)
                if (read <= 0) continue

                var sum = 0.0
                for (i in 0 until read) {
                    val v = buffer[i].toDouble()
                    sum += v * v
                }
                val rms = sqrt(sum / read).coerceAtLeast(1.0)
                val db = 20.0 * ln(rms / 32767.0) / ln(10.0)
                val normalized = ((db + 54.0) / 54.0).coerceIn(0.0, 1.0)
                val level = (normalized * 255.0).toInt().coerceIn(0, 255)
                mainHandler.post { events.success(level) }
                Thread.sleep(48)
            }
        } catch (e: SecurityException) {
            postError(events, "audio_permission", e.message ?: "Microphone permission denied")
        } catch (e: Throwable) {
            if (running.get()) {
                postError(events, "audio_error", e.message ?: "AudioRecord failed")
            }
        } finally {
            try {
                recorder.stop()
            } catch (_: Throwable) {
            }
            recorder.release()
        }
    }

    private fun postError(events: EventChannel.EventSink, code: String, message: String) {
        mainHandler.post { events.error(code, message, null) }
    }
}
