package com.nullcorvus.finance_ai

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Only the explicitly on-device service is allowed; there is no online fallback. */
internal class LocalSpeechBridge(private val activity: Activity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var recognizer: SpeechRecognizer? = null
    private var session = 0L
    private var generation = 0L
    private var segment = 0L
    private var requestedLanguage = "es-ES"
    private var selectedLanguage = "es-ES"
    private var downloadLanguage = "es-ES"
    private var prepared = false
    private var continuing = false
    private var utteranceRunning = false
    private var committed = ""
    private var partial = ""
    private var lastError = ""

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { dispose(); sink = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "initialize") { result.success(null); return }
        if (call.method == "settings") {
            val action = if (lastError.startsWith("speech_permission")) {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${activity.packageName}"))
            } else Intent(Settings.ACTION_VOICE_INPUT_SETTINGS)
            try { activity.startActivity(action); result.success(null) }
            catch (_: Exception) { result.error("speech_settings_unavailable", null, null) }
            return
        }
        val id = call.argument<Number>("session")?.toLong()
        val language = call.argument<String>("language")
        if (id == null || id <= 0 ||
            (call.method in listOf("prepare", "start", "download") &&
                language !in listOf("es-ES", "en-US"))) {
            result.error("speech_provider_error", null, null); return
        }
        try {
            when (call.method) {
                "prepare" -> prepare(id, language!!)
                "start" -> start(id, language!!)
                "stop" -> stop(id)
                "cancel" -> if (id == session) release()
                "download" -> download(id, language!!)
                else -> { result.notImplemented(); return }
            }
            result.success(null)
        } catch (_: SecurityException) {
            fail("speech_permission_denied"); result.success(null)
        } catch (_: Exception) {
            fail("speech_provider_error"); result.success(null)
        }
    }

    private fun emit(type: String, text: String = "", code: String = "", canDownload: Boolean = false) {
        sink?.success(mapOf("session" to session, "type" to type,
            "text" to text, "code" to code, "canDownload" to canDownload))
    }

    private fun ensureRecognizer(): Boolean {
        if (Build.VERSION.SDK_INT < 31 ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)) {
            fail("speech_offline_unavailable"); return false
        }
        if (recognizer == null) {
            recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
            recognizer!!.setRecognitionListener(EmptyListener())
        }
        return true
    }

    private fun prepare(id: Long, language: String) {
        if (continuing || utteranceRunning) release()
        session = id
        if (prepared && requestedLanguage == language && recognizer != null) {
            emit("ready"); return
        }
        release(); requestedLanguage = language; selectedLanguage = language; downloadLanguage = language
        if (!ensureRecognizer()) return
        if (Build.VERSION.SDK_INT < 33) {
            // API 31/32 guarantee local recognition, but expose no model query.
            // An unsupported language is reported safely by startListening.
            prepared = true; emit("ready"); return
        }
        val stamp = generation
        recognizer!!.checkRecognitionSupport(intent(), activity.mainExecutor,
            object : RecognitionSupportCallback {
                override fun onSupportResult(support: RecognitionSupport) {
                    if (stamp != generation || id != session) return
                    val installed = support.installedOnDeviceLanguages
                    val matching = installed.firstOrNull { it.equals(language, ignoreCase = true) }
                        ?: installed.firstOrNull { sameLanguage(it, language) }
                    if (matching != null) {
                        selectedLanguage = matching; prepared = true; emit("ready")
                    } else if (support.pendingOnDeviceLanguages.any { sameLanguage(it, language) }) {
                        downloadLanguage = support.pendingOnDeviceLanguages.first { sameLanguage(it, language) }
                        fail("speech_model_download_pending", true)
                    } else if (support.supportedOnDeviceLanguages.any { sameLanguage(it, language) }) {
                        downloadLanguage = support.supportedOnDeviceLanguages.first { sameLanguage(it, language) }
                        fail("speech_model_missing", true)
                    } else fail("speech_language_unavailable")
                }
                override fun onError(error: Int) {
                    if (stamp != generation || id != session) return
                    if (error == SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT) {
                        // Some local providers cannot enumerate models. Never switch
                        // providers: the local recognizer will validate on start.
                        prepared = true; emit("ready")
                    } else fail(errorCode(error), error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE)
                }
            })
    }

    private fun sameLanguage(first: String, second: String) =
        Locale.forLanguageTag(first).language == Locale.forLanguageTag(second).language

    private fun intent() = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, selectedLanguage)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, selectedLanguage)
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.packageName)
        // Preserve normal endpointer timing. After a terminal callback, rearm
        // while held; short custom silence hints can truncate financial amounts.
    }

    private fun start(id: Long, language: String) {
        session = id
        if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 4107)
            fail("speech_permission_required"); return
        }
        if (requestedLanguage != language || !prepared) {
            fail("speech_language_unavailable"); return
        }
        if (!ensureRecognizer()) return
        committed = ""; partial = ""; continuing = true
        listen()
    }

    private fun listen() {
        // Rearming runs from posted callbacks, outside the method-call handler.
        // Provider/permission failures must still reach the safe error contract.
        try { listenSegment() }
        catch (_: SecurityException) { fail("speech_permission_denied") }
        catch (_: Exception) { fail("speech_provider_error") }
    }

    private fun listenSegment() {
        if (!continuing || recognizer == null) return
        val id = session; val stamp = generation; val chunk = ++segment
        partial = ""; utteranceRunning = true
        recognizer!!.setRecognitionListener(object : EmptyListener() {
            private fun current() = id == session && stamp == generation && chunk == segment
            override fun onReadyForSpeech(params: Bundle?) { if (current() && continuing) emit("listening") }
            override fun onBeginningOfSpeech() { if (current() && continuing) emit("listening") }
            override fun onPartialResults(results: Bundle?) {
                if (!current()) return
                partial = words(results)
                if (partial.isNotBlank()) emit("partial", fullText())
            }
            override fun onResults(results: Bundle?) {
                if (!current()) return
                utteranceRunning = false
                val text = words(results)
                if (text.isBlank() && partial.isNotBlank()) { fail("speech_no_match"); return }
                committed = listOf(committed, text.trim()).filter { it.isNotEmpty() }.joinToString(" ")
                partial = ""
                if (committed.length > 8192) { fail("speech_text_too_long"); return }
                if (continuing) {
                    emit("partial", committed)
                    // Restart only after onResults/onError, never onEndOfSpeech.
                    main.post { if (current() && continuing) listen() }
                } else emit("final", committed)
            }
            override fun onError(error: Int) {
                if (!current()) return
                utteranceRunning = false
                if (continuing && partial.isBlank() &&
                    (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT)) {
                    main.postDelayed({ if (current() && continuing) listen() }, 120)
                } else if (!continuing && partial.isBlank() && committed.isNotBlank() &&
                    (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT)) {
                    emit("final", committed)
                } else fail(errorCode(error), error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE)
            }
        })
        recognizer!!.startListening(intent())
    }

    private fun words(results: Bundle?) = results
        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
    private fun fullText() = listOf(committed, partial.trim()).filter { it.isNotEmpty() }.joinToString(" ")

    private fun stop(id: Long) {
        if (id != session) return
        continuing = false
        if (utteranceRunning) recognizer?.stopListening()
        else emit("final", committed)
    }

    private fun download(id: Long, language: String) {
        release(); session = id; requestedLanguage = language
        selectedLanguage = if (sameLanguage(downloadLanguage, language)) downloadLanguage else language
        if (!ensureRecognizer()) return
        if (Build.VERSION.SDK_INT < 33) { fail("speech_language_unavailable"); return }
        recognizer!!.triggerModelDownload(intent())
        // Download is an explicit setup action; it must never open the mic.
        fail("speech_model_download_pending", true, releaseRecognizer = false)
    }

    private fun errorCode(error: Int): String = when (error) {
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "speech_permission_denied"
        SpeechRecognizer.ERROR_AUDIO -> "speech_microphone_busy"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY, SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "speech_busy"
        SpeechRecognizer.ERROR_NO_MATCH -> "speech_no_match"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "speech_no_speech"
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "speech_language_unavailable"
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "speech_model_missing"
        else -> "speech_provider_error"
    }

    private fun fail(code: String, canDownload: Boolean = false, releaseRecognizer: Boolean = true) {
        lastError = code
        emit("error", code = code, canDownload = canDownload)
        if (releaseRecognizer) release()
    }

    private fun release() {
        generation++; segment++; continuing = false; utteranceRunning = false; prepared = false
        main.removeCallbacksAndMessages(null)
        val previous = recognizer; recognizer = null
        // A failed provider may also throw during cancel. Still attempt destroy.
        try { previous?.cancel() } catch (_: Exception) { }
        try { previous?.destroy() } catch (_: Exception) { }
    }

    fun pause() {
        if (continuing || utteranceRunning) fail("speech_session_ended")
    }
    fun dispose() { release() }

    private open class EmptyListener : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) = Unit
        override fun onBeginningOfSpeech() = Unit
        override fun onRmsChanged(rmsdB: Float) = Unit
        override fun onBufferReceived(buffer: ByteArray?) = Unit
        override fun onEndOfSpeech() = Unit
        override fun onError(error: Int) = Unit
        override fun onResults(results: Bundle?) = Unit
        override fun onPartialResults(partialResults: Bundle?) = Unit
        override fun onEvent(eventType: Int, params: Bundle?) = Unit
    }
}
