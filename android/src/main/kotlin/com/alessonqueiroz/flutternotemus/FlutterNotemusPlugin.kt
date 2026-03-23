package com.alessonqueiroz.flutternotemus

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Process
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Arrays
import kotlin.math.max

/** Android native audio bridge for flutter_notemus MIDI playback. */
class FlutterNotemusPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    companion object {
        init {
            System.loadLibrary("flutter_notemus_native")
        }

        private const val CHANNEL_NAME = "flutter_notemus/native_audio"
    }

    private lateinit var channel: MethodChannel

    private val engineLock = Any()
    private var nativeHandle: Long = 0L

    private var audioTrack: AudioTrack? = null
    private var renderThread: Thread? = null

    @Volatile
    private var renderLoopRunning = false

    @Volatile
    private var playing = false

    private var outputChannels = 2
    private var frameCount = 256

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        releaseEngineAndAudio()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "nativeInitialize" -> handleInitialize(call, result)
                "nativeSequencerStart" -> handleStart(result)
                "nativeSequencerStop" -> handleStop(result)
                "nativeRelease" -> {
                    releaseEngineAndAudio()
                    result.success(null)
                }
                "nativeSequencerAddNote" -> handleAddNote(call, result)
                "nativeSequencerAddMetronome" -> handleAddMetronome(call, result)
                "nativeSequencerSetTempo" -> handleSetTempo(call, result)
                "nativeSequencerSetTicksPerQuarter" -> handleSetTicksPerQuarter(call, result)
                "nativeSequencerSetTimeSignature" -> handleSetTimeSignature(call, result)
                "nativeSequencerClear" -> withEngine(result) { handle ->
                    nativeClear(handle)
                    result.success(null)
                }
                "nativeSequencerProcessTies" -> withEngine(result) { handle ->
                    nativeProcessTies(handle)
                    result.success(null)
                }
                "nativeIsReady" -> {
                    val ready = synchronized(engineLock) {
                        nativeHandle != 0L && nativeIsReady(nativeHandle)
                    } && audioTrack != null
                    result.success(ready)
                }
                else -> result.notImplemented()
            }
        } catch (t: Throwable) {
            result.error("native_audio_error", t.message, null)
        }
    }

    private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
        val sampleRate = numberArg(call, "sampleRate", 48000).coerceIn(8000, 192000)
        val primarySoundFont = call.argument<String>("primarySoundFontPath") ?: ""
        val metronomeSoundFont = call.argument<String>("metronomeSoundFontPath") ?: ""

        releaseEngineAndAudio()

        val handle = nativeCreateEngine(sampleRate)
        if (handle == 0L) {
            result.success(false)
            return
        }

        synchronized(engineLock) {
            nativeHandle = handle
            nativeSetSoundFontPaths(handle, primarySoundFont, metronomeSoundFont)
        }

        if (!setupAudio(sampleRate)) {
            releaseEngineAndAudio()
            result.success(false)
            return
        }

        result.success(true)
    }

    private fun handleStart(result: MethodChannel.Result) {
        withEngine(result) { handle ->
            synchronized(engineLock) {
                nativeStart(handle)
            }
            playing = true
            audioTrack?.play()
            result.success(null)
        }
    }

    private fun handleStop(result: MethodChannel.Result) {
        withEngine(result) { handle ->
            playing = false
            synchronized(engineLock) {
                nativeStop(handle)
            }
            audioTrack?.pause()
            audioTrack?.flush()
            result.success(null)
        }
    }

    private fun handleAddNote(call: MethodCall, result: MethodChannel.Result) {
        withEngine(result) { handle ->
            val midiNote = numberArg(call, "midiNote", 60).coerceIn(0, 127)
            val startTick = numberArg(call, "startTick", 0)
            val durationTicks = max(1, numberArg(call, "durationTicks", 1))
            val velocity = numberArg(call, "velocity", 100).coerceIn(1, 127)
            val channel = numberArg(call, "channel", 0).coerceIn(0, 15)
            val isTied = boolArg(call, "isTied", false)

            synchronized(engineLock) {
                nativeAddNote(
                    handle = handle,
                    midiNote = midiNote,
                    startTick = startTick,
                    durationTicks = durationTicks,
                    velocity = velocity,
                    channel = channel,
                    isTied = isTied,
                )
            }
            result.success(null)
        }
    }

    private fun handleAddMetronome(call: MethodCall, result: MethodChannel.Result) {
        withEngine(result) { handle ->
            val totalTicks = max(0, numberArg(call, "durationTicks", 0))
            val countIn = max(0, numberArg(call, "countIn", 0))
            synchronized(engineLock) {
                nativeAddMetronome(
                    handle = handle,
                    totalTicks = totalTicks,
                    countInBeats = countIn,
                )
            }
            result.success(null)
        }
    }

    private fun handleSetTempo(call: MethodCall, result: MethodChannel.Result) {
        withEngine(result) { handle ->
            val bpm = numberArg(call, "bpm", 120).coerceIn(20, 400)
            synchronized(engineLock) {
                nativeSetTempo(handle, bpm)
            }
            result.success(null)
        }
    }

    private fun handleSetTicksPerQuarter(call: MethodCall, result: MethodChannel.Result) {
        withEngine(result) { handle ->
            val ticksPerQuarter = numberArg(call, "ticksPerQuarter", 960).coerceIn(24, 9600)
            synchronized(engineLock) {
                nativeSetTicksPerQuarter(handle, ticksPerQuarter)
            }
            result.success(null)
        }
    }

    private fun handleSetTimeSignature(call: MethodCall, result: MethodChannel.Result) {
        withEngine(result) { handle ->
            val numerator = max(1, numberArg(call, "numerator", 4))
            val denominator = max(1, numberArg(call, "denominator", 4))
            synchronized(engineLock) {
                nativeSetTimeSignature(handle, numerator, denominator)
            }
            result.success(null)
        }
    }

    private fun setupAudio(sampleRate: Int): Boolean {
        val minBufferBytes = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_STEREO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBufferBytes <= 0) {
            return false
        }

        outputChannels = 2
        frameCount = max(256, minBufferBytes / (2 * outputChannels))
        val bufferSizeBytes = max(minBufferBytes, frameCount * 2 * outputChannels)

        val track = AudioTrack(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build(),
            AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(sampleRate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                .build(),
            bufferSizeBytes,
            AudioTrack.MODE_STREAM,
            AudioManager.AUDIO_SESSION_ID_GENERATE,
        )

        if (track.state != AudioTrack.STATE_INITIALIZED) {
            track.release()
            return false
        }

        audioTrack = track
        startRenderThread()
        return true
    }

    private fun startRenderThread() {
        stopRenderThread()
        renderLoopRunning = true
        playing = false
        renderThread = Thread {
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)
            val sampleBuffer = ShortArray(frameCount * outputChannels)
            while (renderLoopRunning) {
                val track = audioTrack ?: break
                val handle = synchronized(engineLock) { nativeHandle }
                if (handle == 0L || !playing) {
                    Arrays.fill(sampleBuffer, 0.toShort())
                } else {
                    synchronized(engineLock) {
                        nativeRender(
                            handle = handle,
                            output = sampleBuffer,
                            frames = frameCount,
                            channels = outputChannels,
                        )
                    }
                }
                track.write(sampleBuffer, 0, sampleBuffer.size, AudioTrack.WRITE_BLOCKING)
            }
        }.apply {
            name = "NotemusNativeAudioThread"
            isDaemon = true
            start()
        }
    }

    private fun stopRenderThread() {
        renderLoopRunning = false
        renderThread?.join(250)
        renderThread = null
    }

    private fun releaseEngineAndAudio() {
        playing = false
        stopRenderThread()

        audioTrack?.let { track ->
            track.pause()
            track.flush()
            track.release()
        }
        audioTrack = null

        val handleToDestroy = synchronized(engineLock) {
            val current = nativeHandle
            nativeHandle = 0L
            current
        }
        if (handleToDestroy != 0L) {
            nativeDestroyEngine(handleToDestroy)
        }
    }

    private inline fun withEngine(
        result: MethodChannel.Result,
        block: (Long) -> Unit,
    ) {
        val handle = synchronized(engineLock) { nativeHandle }
        if (handle == 0L) {
            result.error("native_not_ready", "Native audio backend is not initialized.", null)
            return
        }
        block(handle)
    }

    private fun numberArg(call: MethodCall, name: String, defaultValue: Int): Int {
        return (call.argument<Number>(name)?.toInt()) ?: defaultValue
    }

    private fun boolArg(call: MethodCall, name: String, defaultValue: Boolean): Boolean {
        return call.argument<Boolean>(name) ?: defaultValue
    }

    private external fun nativeCreateEngine(sampleRate: Int): Long
    private external fun nativeDestroyEngine(handle: Long)
    private external fun nativeSetSoundFontPaths(
        handle: Long,
        primarySoundFontPath: String,
        metronomeSoundFontPath: String,
    )
    private external fun nativeSetTempo(handle: Long, bpm: Int)
    private external fun nativeSetTicksPerQuarter(handle: Long, ticksPerQuarter: Int)
    private external fun nativeSetTimeSignature(handle: Long, numerator: Int, denominator: Int)
    private external fun nativeClear(handle: Long)
    private external fun nativeAddNote(
        handle: Long,
        midiNote: Int,
        startTick: Int,
        durationTicks: Int,
        velocity: Int,
        channel: Int,
        isTied: Boolean,
    )
    private external fun nativeAddMetronome(handle: Long, totalTicks: Int, countInBeats: Int)
    private external fun nativeProcessTies(handle: Long)
    private external fun nativeStart(handle: Long)
    private external fun nativeStop(handle: Long)
    private external fun nativeRender(handle: Long, output: ShortArray, frames: Int, channels: Int)
    private external fun nativeIsReady(handle: Long): Boolean
}
