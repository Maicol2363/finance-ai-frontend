package com.nullcorvus.finance_ai

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import org.vosk.LibVosk
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.ExecutorService
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference
import javax.net.ssl.HttpsURLConnection

/** Model loading, downloads and decoding run off the UI thread. Audio only lives in RAM. */
internal class OfflineSpeechEngine(context: Context,
    modelRoot: File = File(context.noBackupFilesDir, "speech-models"),
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()) {
    private val main = Handler(Looper.getMainLooper())
    private val cancellationWorker = Executors.newSingleThreadExecutor()
    private val store = OfflineModelStore(modelRoot)
    private val epoch = AtomicLong()
    private val capture = AtomicReference<Capture?>()
    @Volatile private var disposed = false
    private var model: Model? = null // Accessed only by the worker.
    private var modelLanguage = ""
    private var download: Download? = null // Accessed only on the main thread.

    private fun logLinkageFailure(error: LinkageError) {
        // Native initialization details are useful for device diagnosis, but
        // keep logs bounded and exclude characters used in URLs/credentials.
        val causes = generateSequence(error as Throwable?) { it.cause }
            .take(4)
            .joinToString(" <- ") { cause ->
                val detail = (cause.message ?: "unavailable")
                    .replace(Regex("[^A-Za-z0-9 ._:/()\\[\\]-]"), "?")
                    .take(180)
                "${cause.javaClass.simpleName}: $detail"
            }
        Log.e("FinanceAiSpeech", "Offline engine linkage failure: $causes")
    }

    private class Capture(val epoch: Long) {
        val stopped = AtomicBoolean()
        val cancelled = AtomicBoolean()
    }
    private class Download(val language: String) {
        val cancelled = AtomicBoolean()
        val connection = AtomicReference<HttpsURLConnection?>()
        @Volatile var stage = "requested"
        @Volatile var progress: Int? = null
    }

    fun installed(language: String) = store.installed(OfflineModelStore.spec(language))
    val downloading: Boolean get() = download != null
    fun downloadStatus(): Pair<String, Int?>? = download?.let { it.stage to it.progress }

    private fun load(language: String): Boolean {
        val spec = OfflineModelStore.spec(language)
        if (!store.installed(spec)) return false
        if (model != null && modelLanguage == language) return true
        model?.close(); model = null; modelLanguage = ""
        LibVosk.vosk_set_log_level(-1)
        model = Model(store.directory(spec).path)
        modelLanguage = language
        return true
    }

    fun prepare(language: String, complete: (String?) -> Unit) {
        cancelCapture()
        val stamp = epoch.get()
        worker.execute {
            if (disposed || epoch.get() != stamp) return@execute
            val code = try {
                if (load(language)) null else "speech_fallback_model_missing"
            } catch (error: LinkageError) {
                logLinkageFailure(error)
                "speech_fallback_unavailable"
            }
              catch (_: OutOfMemoryError) { "speech_fallback_memory" }
              catch (_: Exception) {
                  store.invalidate(OfflineModelStore.spec(language))
                  "speech_model_invalid"
              }
            main.post { if (!disposed && epoch.get() == stamp) complete(code) }
        }
    }

    fun start(language: String, event: (String, String, String) -> Unit) {
        cancelCapture()
        val run = Capture(epoch.get())
        capture.set(run)
        fun emit(type: String, text: String = "", code: String = "") {
            main.post {
                if (!disposed && epoch.get() == run.epoch && !run.cancelled.get()) event(type, text, code)
            }
        }
        worker.execute {
            var recorder: AudioRecord? = null
            var decoder: Recognizer? = null
            val buffer = ShortArray(1600)
            try {
                if (disposed || run.cancelled.get()) return@execute
                if (run.stopped.get()) { emit("error", code = "speech_no_speech"); return@execute }
                if (!load(language)) { emit("error", code = "speech_fallback_model_missing"); return@execute }
                if (run.cancelled.get()) return@execute
                if (run.stopped.get()) { emit("error", code = "speech_no_speech"); return@execute }
                decoder = Recognizer(model!!, 16000f)
                val minimum = AudioRecord.getMinBufferSize(16000, AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT)
                if (minimum <= 0) { emit("error", code = "speech_microphone_busy"); return@execute }
                recorder = AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, 16000,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                    maxOf(minimum, 6400))
                if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                    emit("error", code = "speech_microphone_busy"); return@execute
                }
                if (run.cancelled.get()) return@execute
                if (run.stopped.get()) { emit("error", code = "speech_no_speech"); return@execute }
                recorder.startRecording()
                if (recorder.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                    emit("error", code = "speech_microphone_busy"); return@execute
                }
                emit("listening")
                var committed = ""
                var partial = ""
                var previous = ""
                while (!run.stopped.get() && !run.cancelled.get() && !disposed) {
                    val count = recorder.read(buffer, 0, buffer.size)
                    if (count < 0) { emit("error", code = "speech_microphone_busy"); return@execute }
                    if (count == 0) continue
                    if (decoder.acceptWaveForm(buffer, count)) {
                        val phrase = JSONObject(decoder.result).optString("text").trim()
                        committed = listOf(committed, phrase).filter { it.isNotEmpty() }.joinToString(" ")
                        partial = ""
                    } else partial = JSONObject(decoder.partialResult).optString("partial").trim()
                    val full = listOf(committed, partial).filter { it.isNotEmpty() }.joinToString(" ")
                    if (full.length > 8192) { emit("error", code = "speech_text_too_long"); return@execute }
                    if (full.isNotBlank() && full != previous) { previous = full; emit("partial", full) }
                }
                recorder.stop()
                if (!run.cancelled.get() && !disposed) {
                    val tail = JSONObject(decoder.finalResult).optString("text").trim()
                    if (tail.isBlank() && partial.isNotBlank()) {
                        emit("error", code = "speech_no_match")
                    } else {
                        val final = listOf(committed, tail).filter { it.isNotEmpty() }.joinToString(" ")
                        if (final.isBlank()) emit("error", code = "speech_no_speech") else emit("final", final)
                    }
                }
            } catch (_: SecurityException) { emit("error", code = "speech_permission_denied") }
              catch (error: LinkageError) {
                  logLinkageFailure(error)
                  emit("error", code = "speech_fallback_unavailable")
              }
              catch (_: OutOfMemoryError) { emit("error", code = "speech_fallback_memory") }
              catch (_: Exception) { emit("error", code = "speech_provider_error") }
            finally {
                buffer.fill(0)
                try { recorder?.stop() } catch (_: Exception) { }
                recorder?.release()
                decoder?.close()
                capture.compareAndSet(run, null)
            }
        }
    }

    fun stop() { capture.get()?.stopped?.set(true) }
    fun cancelCapture() {
        epoch.incrementAndGet()
        capture.get()?.let { it.cancelled.set(true); it.stopped.set(true) }
    }

    fun download(language: String, progress: (String, Int?) -> Unit, complete: (String?) -> Unit) {
        download?.let { progress(it.stage, it.progress); return }
        cancelCapture()
        val job = Download(language)
        download = job
        progress("requested", null)
        worker.execute {
            val code = try {
                store.download(OfflineModelStore.spec(language),
                    cancelled = { disposed || job.cancelled.get() },
                    progress = { stage, percent ->
                        job.stage = stage; job.progress = percent
                        main.post { if (!disposed && download === job) progress(stage, percent) }
                    }, connected = { connection -> job.connection.set(connection) })
                null
            } catch (_: Exception) { "speech_model_download_failed" }
            main.post {
                if (!disposed && download === job) {
                    download = null
                    if (!job.cancelled.get()) complete(code)
                }
            }
        }
    }

    fun cancelDownload() {
        download?.let { job ->
            job.cancelled.set(true)
            val connection = job.connection.getAndSet(null)
            if (connection != null) cancellationWorker.execute { connection.disconnect() }
        }
        download = null
    }
    fun dispose() {
        if (disposed) return
        disposed = true
        cancelCapture(); cancelDownload()
        worker.execute { model?.close(); model = null }
        worker.shutdown()
        cancellationWorker.shutdown()
    }
}
