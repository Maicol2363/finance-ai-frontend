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

/** Only the explicitly on-device service or our offline decoder is allowed. */
internal class LocalSpeechBridge(private val activity: Activity,
    private val offline: OfflineSpeechEngine = OfflineSpeechEngine(activity),
    private val deviceRecognitionAvailable: () -> Boolean = {
        Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)
    }) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private val preferences = activity.getSharedPreferences("voice_setup", Activity.MODE_PRIVATE)
    private var sink: EventChannel.EventSink? = null
    private var pendingEvent: Map<String, Any?>? = null
    private var recognizer: SpeechRecognizer? = null
    private var session = 0L
    private var generation = 0L
    private var segment = 0L
    private var requestedLanguage = "es-ES"
    private var selectedLanguage = "es-ES"
    private var usingOffline = false
    private var fallbackReason = "none"
    private var prepared = false
    private var continuing = false
    private var utteranceRunning = false
    private var committed = ""
    private var partial = ""
    private var lastError = ""
    private var emptySegments = 0

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        pendingEvent?.let { events?.success(it) }
        pendingEvent = null
    }
    override fun onCancel(arguments: Any?) { release(); offline.cancelDownload(); sink = null; pendingEvent = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "initialize") { result.success(null); return }
        if (call.method == "settings") {
            // Recovery only offers this action for this app's microphone permission.
            // Assistant/keyboard settings do not configure our local recognizer.
            val action = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:${activity.packageName}"))
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
                "cancel" -> if (id == session) { offline.cancelDownload(); release() }
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
        val event = mapOf("session" to session, "type" to type,
            "text" to text, "code" to code, "canDownload" to canDownload,
            "engine" to if (usingOffline) "integrated" else "device",
            "reason" to fallbackReason, "apiLevel" to Build.VERSION.SDK_INT)
        if (sink == null) pendingEvent = event else sink?.success(event)
    }

    private fun emitDownload(stage: String, progress: Int?) {
        sink?.success(mapOf("session" to session, "type" to "download",
            "stage" to stage, "progress" to progress, "engine" to "integrated"))
    }

    private fun ensureRecognizer(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT < 31 || !deviceRecognitionAvailable()) false
            else {
                if (recognizer == null) {
                    recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
                    recognizer!!.setRecognitionListener(EmptyListener())
                }
                true
            }
        } catch (_: Exception) { false }
    }

    private fun prepare(id: Long, language: String) {
        session = id
        val sameRequestedLanguage = requestedLanguage == language
        requestedLanguage = language
        if (offline.downloading) {
            offline.downloadStatus()?.let { emitDownload(it.first, it.second) }
            return
        }
        if (preferences.getBoolean("integrated_$language", false)) {
            useFallback(id, language, false); return
        }
        if (prepared && sameRequestedLanguage && recognizer != null) {
            emit("ready"); return
        }
        release(); requestedLanguage = language; selectedLanguage = language; usingOffline = false
        fallbackReason = "none"
        if (!ensureRecognizer()) {
            fallbackReason = "native_service_missing"
            useFallback(id, language, false); return
        }
        if (Build.VERSION.SDK_INT < 33) {
            // API 31/32 guarantee local recognition, but expose no model query.
            // An unsupported language is reported safely by startListening.
            prepared = true; emit("ready"); return
        }
        val stamp = generation
        // Provider enumeration is advisory. A stalled check must not block a
        // functioning, explicitly on-device recognizer or open the microphone.
        val supportDeadline = Runnable {
            if (stamp == generation && id == session && !prepared) {
                prepared = true; emit("ready")
            }
        }
        main.postDelayed(supportDeadline, 1500)
        try { recognizer!!.checkRecognitionSupport(intent(), activity.mainExecutor,
            object : RecognitionSupportCallback {
                override fun onSupportResult(support: RecognitionSupport) {
                    if (stamp != generation || id != session || prepared) return
                    main.removeCallbacks(supportDeadline)
                    val installed = support.installedOnDeviceLanguages
                    val matching = installed.firstOrNull { it.equals(language, ignoreCase = true) }
                        ?: installed.firstOrNull { sameLanguage(it, language) }
                    if (matching != null) {
                        selectedLanguage = matching; prepared = true; emit("ready")
                    } else {
                        // Some providers report a pending model update although
                        // the current model still works. Validate on explicit start.
                        prepared = true; emit("ready")
                    }
                }
                override fun onError(error: Int) {
                    if (stamp != generation || id != session || prepared) return
                    main.removeCallbacks(supportDeadline)
                    prepared = true; emit("ready")
                }
            }) } catch (_: Exception) {
                main.removeCallbacks(supportDeadline)
                prepared = true; emit("ready")
            }
    }

    private fun useFallback(id: Long, language: String, listen: Boolean) {
        val resume = listen && continuing
        release(); session = id; requestedLanguage = language
        usingOffline = true; continuing = resume
        val stamp = generation
        offline.prepare(language) { code ->
            if (stamp != generation || id != session) return@prepare
            if (code != null) {
                fail(code, code == "speech_fallback_model_missing" || code == "speech_model_invalid")
            } else {
                prepared = true
                if (resume && continuing) listenOffline() else emit("ready")
            }
        }
    }

    private fun listenOffline() {
        utteranceRunning = true
        val id = session; val stamp = generation
        offline.start(requestedLanguage) { type, text, code ->
            if (id != session || stamp != generation) return@start
            if (type == "final" || type == "error") { utteranceRunning = false; continuing = false }
            if (type == "error") fail(code, code == "speech_fallback_model_missing")
            else emit(type, text)
        }
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
            if (preferences.getBoolean("microphone_requested", false) &&
                !activity.shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO)) {
                fail("speech_permission_denied"); return
            }
            preferences.edit().putBoolean("microphone_requested", true).apply()
            activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 4107)
            fail("speech_permission_required"); return
        }
        if (requestedLanguage != language || !prepared) {
            fail("speech_language_unavailable"); return
        }
        committed = ""; partial = ""; emptySegments = 0; continuing = true
        if (usingOffline) listenOffline()
        else if (ensureRecognizer()) listen()
        else { fallbackReason = "native_service_missing"; useFallback(id, language, true) }
    }

    private fun listen() {
        // Rearming runs from posted callbacks, outside the method-call handler.
        // Provider/permission failures must still reach the safe error contract.
        try { listenSegment() }
        catch (_: SecurityException) { fail("speech_permission_denied") }
        catch (_: Exception) {
            fallbackReason = "native_service_error"
            preferences.edit().putBoolean("integrated_$requestedLanguage", true).apply()
            if (continuing && partial.isBlank() && committed.isBlank()) useFallback(session, requestedLanguage, true)
            else fail("speech_provider_error")
        }
    }

    private fun listenSegment() {
        if (!continuing || recognizer == null) return
        val id = session; val stamp = generation; val chunk = ++segment
        partial = ""; utteranceRunning = true
        val openingDeadline = Runnable {
            if (id == session && stamp == generation && chunk == segment && continuing &&
                committed.isBlank() && partial.isBlank()) {
                fallbackReason = "native_service_timeout"
                preferences.edit().putBoolean("integrated_$requestedLanguage", true).apply()
                useFallback(id, requestedLanguage, true)
            }
        }
        val inputDeadline = Runnable {
            if (id == session && stamp == generation && chunk == segment && continuing) {
                if (fullText().isNotBlank()) {
                    // Preserve the last visible hypothesis if terminal callbacks stall.
                    continuing = false; utteranceRunning = false; segment++
                    try { recognizer?.cancel() } catch (_: Exception) { }
                    emit("final", fullText())
                } else if (offline.installed(requestedLanguage)) {
                    fallbackReason = "native_service_timeout"
                    preferences.edit().putBoolean("integrated_$requestedLanguage", true).apply()
                    useFallback(id, requestedLanguage, true)
                } else fail("speech_no_speech")
            }
        }
        main.postDelayed(openingDeadline, 6000)
        main.postDelayed(inputDeadline, 15000)
        recognizer!!.setRecognitionListener(object : EmptyListener() {
            private fun current() = id == session && stamp == generation && chunk == segment
            override fun onReadyForSpeech(params: Bundle?) {
                if (current() && continuing) { main.removeCallbacks(openingDeadline); emit("listening") }
            }
            override fun onBeginningOfSpeech() {
                if (current() && continuing) { main.removeCallbacks(openingDeadline); emit("listening") }
            }
            override fun onPartialResults(results: Bundle?) {
                if (!current()) return
                partial = words(results)
                if (partial.isNotBlank()) {
                    emptySegments = 0
                    main.removeCallbacks(openingDeadline)
                    main.removeCallbacks(inputDeadline)
                    main.postDelayed(inputDeadline, 15000)
                    emit("partial", fullText())
                }
            }
            override fun onResults(results: Bundle?) {
                if (!current()) return
                main.removeCallbacks(openingDeadline)
                main.removeCallbacks(inputDeadline)
                utteranceRunning = false
                val text = words(results)
                if (text.isBlank() && partial.isNotBlank()) { fail("speech_no_match"); return }
                if (text.isBlank() && continuing) {
                    handleEmptySegment { if (current() && continuing) listen() }
                    return
                }
                if (text.isNotBlank()) emptySegments = 0
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
                main.removeCallbacks(openingDeadline)
                main.removeCallbacks(inputDeadline)
                utteranceRunning = false
                if (error in listOf(SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
                        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED, SpeechRecognizer.ERROR_SERVER,
                        SpeechRecognizer.ERROR_SERVER_DISCONNECTED, SpeechRecognizer.ERROR_CLIENT,
                        SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT)) {
                    fallbackReason = if (error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ||
                        error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED) "native_model_missing" else "native_service_error"
                    preferences.edit().putBoolean("integrated_$requestedLanguage", true).apply()
                    if (continuing && partial.isBlank() && committed.isBlank()) {
                        useFallback(id, requestedLanguage, true); return
                    }
                    val installed = offline.installed(requestedLanguage)
                    fail(if (installed) "speech_provider_error" else "speech_fallback_model_missing", !installed)
                    return
                }
                if (continuing && partial.isBlank() &&
                    (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT)) {
                    handleEmptySegment { if (current() && continuing) listen() }
                } else if (!continuing && partial.isBlank() && committed.isNotBlank() &&
                    (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT)) {
                    emit("final", committed)
                } else fail(errorCode(error), error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE)
            }
        })
        recognizer!!.startListening(intent())
    }

    private fun handleEmptySegment(retry: () -> Unit) {
        if (committed.isNotBlank()) {
            // A pause after valid words ends review without replacing those words
            // with an unrelated fallback engine hypothesis.
            continuing = false
            emit("final", committed)
            return
        }
        emptySegments++
        if (emptySegments >= 2) {
            if (offline.installed(requestedLanguage)) {
                fallbackReason = "native_service_timeout"
                preferences.edit().putBoolean("integrated_$requestedLanguage", true).apply()
                useFallback(session, requestedLanguage, true)
            } else fail("speech_no_speech")
        } else main.postDelayed(retry, 120)
    }

    private fun words(results: Bundle?) = results
        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
    private fun fullText() = listOf(committed, partial.trim()).filter { it.isNotEmpty() }.joinToString(" ")

    private fun stop(id: Long) {
        if (id != session) return
        continuing = false
        if (utteranceRunning && usingOffline) offline.stop()
        else if (utteranceRunning) recognizer?.stopListening()
        else emit("final", committed)
    }

    private fun download(id: Long, language: String) {
        release(); session = id; requestedLanguage = language
        usingOffline = true
        preferences.edit().putBoolean("integrated_$language", true).apply()
        offline.download(language,
            progress = { stage, progress -> if (requestedLanguage == language) emitDownload(stage, progress) },
            complete = { code ->
                if (requestedLanguage == language) {
                    if (code != null) fail(code, true) else {
                        emitDownload("loading", null)
                        useFallback(session, language, false)
                    }
                }
            })
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
        offline.cancelCapture()
        main.removeCallbacksAndMessages(null)
        val previous = recognizer; recognizer = null
        // A failed provider may also throw during cancel. Still attempt destroy.
        try { previous?.cancel() } catch (_: Exception) { }
        try { previous?.destroy() } catch (_: Exception) { }
    }

    fun pause() {
        if (continuing || utteranceRunning) fail("speech_session_ended")
    }
    fun dispose() { release(); offline.dispose() }

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
