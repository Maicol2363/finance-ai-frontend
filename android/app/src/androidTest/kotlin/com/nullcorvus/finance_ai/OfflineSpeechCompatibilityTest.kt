package com.nullcorvus.finance_ai

import android.app.Activity
import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.vosk.LibVosk
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.Executors

/** Public fixtures only: this suite never opens a microphone or calls the finance API. */
@RunWith(AndroidJUnit4::class)
class OfflineSpeechCompatibilityTest {
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private fun root() = File(instrumentation.targetContext.cacheDir,
        "voice-verification-${System.nanoTime()}").also { it.mkdirs() }

    private fun install(root: File, spec: OfflineModelSpec): OfflineModelStore {
        val archive = File(root, "${spec.name}.zip")
        instrumentation.context.assets.open("${spec.name}.zip").use { input ->
            archive.outputStream().use { input.copyTo(it) }
        }
        val store = OfflineModelStore(File(root, "models"))
        store.install(spec, archive)
        archive.delete()
        return store
    }

    @Test fun preparationBeforeEventSubscriptionIsReplayed() {
        val root = root()
        val activity = instrumentation.startActivitySync(Intent(instrumentation.targetContext,
            VoiceProbeActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        var bridge: LocalSpeechBridge? = null
        val worker = Executors.newSingleThreadExecutor()
        val received = java.util.concurrent.CopyOnWriteArrayList<Map<*, *>>()
        try {
            instrumentation.runOnMainSync {
                bridge = LocalSpeechBridge(activity, OfflineSpeechEngine(activity, File(root, "models"), worker), { false })
                bridge!!.onMethodCall(MethodCall("prepare", mapOf("session" to 991L, "language" to "es-ES")),
                    object : MethodChannel.Result {
                        override fun success(value: Any?) = Unit
                        override fun error(code: String, message: String?, details: Any?) { fail(code) }
                        override fun notImplemented() { fail("prepare_unavailable") }
                    })
            }
            // Wait for the worker and main callback before attaching the sink.
            worker.submit { }.get(30, TimeUnit.SECONDS)
            instrumentation.waitForIdleSync()
            instrumentation.runOnMainSync {
                bridge!!.onListen(null, object : EventChannel.EventSink {
                    override fun success(value: Any?) { if (value is Map<*, *>) received.add(value) }
                    override fun error(code: String, message: String?, details: Any?) { fail(code) }
                    override fun endOfStream() = Unit
                })
            }
            assertEquals(1, received.size)
            assertEquals(991L, received.single()["session"])
            assertEquals("speech_fallback_model_missing", received.single()["code"])
        } finally {
            instrumentation.runOnMainSync { bridge?.dispose(); activity.finish() }
            root.deleteRecursively()
        }
    }

    @Test fun bothPinnedModelsLoadAndPublicEnglishAudioDecodesOffline() {
        val root = root()
        try {
            val store = install(root, OfflineModelStore.spanish)
            install(root, OfflineModelStore.english)
            LibVosk.vosk_set_log_level(-1)
            Model(store.directory(OfflineModelStore.spanish).path).use { model ->
                Recognizer(model, 16000f).use { decoder ->
                    decoder.acceptWaveForm(ShortArray(16000), 16000)
                    assertEquals("", JSONObject(decoder.finalResult).optString("text"))
                }
            }
            val wave = instrumentation.context.assets.open("test.wav").use { it.readBytes() }
            val header = ByteBuffer.wrap(wave).order(ByteOrder.LITTLE_ENDIAN)
            var position = 12
            var decoded = ""
            Model(store.directory(OfflineModelStore.english).path).use { model ->
                Recognizer(model, 16000f).use { decoder ->
                    while (position + 8 <= wave.size) {
                        val name = String(wave, position, 4, Charsets.US_ASCII)
                        val size = header.getInt(position + 4)
                        assertTrue(size >= 0 && position + 8L + size <= wave.size)
                        if (name == "fmt ") {
                            assertEquals(1, header.getShort(position + 8).toInt())
                            assertEquals(1, header.getShort(position + 10).toInt())
                            assertEquals(16000, header.getInt(position + 12))
                            assertEquals(16, header.getShort(position + 22).toInt())
                        }
                        if (name == "data") {
                            var audio = position + 8
                            val end = audio + size
                            while (audio < end) {
                                val count = minOf(3200, end - audio)
                                val samples = wave.copyOfRange(audio, audio + count)
                                if (decoder.acceptWaveForm(samples, samples.size)) {
                                    decoded += " " + JSONObject(decoder.result).optString("text")
                                }
                                samples.fill(0)
                                audio += count
                            }
                            decoded += " " + JSONObject(decoder.finalResult).optString("text")
                        }
                        position += 8 + size + size % 2
                    }
                }
            }
            assertTrue(decoded.contains("zero") && decoded.contains("one"))
            wave.fill(0)
        } finally { root.deleteRecursively() }
    }

    private fun fallbackPreparation(withModel: Boolean) {
        val root = root()
        var bridge: LocalSpeechBridge? = null
        var activity: Activity? = null
        val events = java.util.concurrent.CopyOnWriteArrayList<Map<*, *>>()
        val completed = CountDownLatch(1)
        try {
            if (withModel) install(root, OfflineModelStore.spanish)
            activity = instrumentation.startActivitySync(Intent(instrumentation.targetContext,
                VoiceProbeActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            instrumentation.runOnMainSync {
                bridge = LocalSpeechBridge(activity!!,
                    OfflineSpeechEngine(activity!!, File(root, "models")), { false })
                bridge!!.onListen(null, object : EventChannel.EventSink {
                    override fun success(value: Any?) {
                        if (value is Map<*, *>) { events.add(value); completed.countDown() }
                    }
                    override fun error(code: String, message: String?, details: Any?) { fail(code) }
                    override fun endOfStream() = Unit
                })
                bridge!!.onMethodCall(MethodCall("prepare", mapOf("session" to 700L, "language" to "es-ES")),
                    object : MethodChannel.Result {
                        override fun success(value: Any?) = Unit
                        override fun error(code: String, message: String?, details: Any?) { fail(code) }
                        override fun notImplemented() { fail("prepare_unavailable") }
                    })
            }
            assertTrue("Local preparation did not finish", completed.await(30, TimeUnit.SECONDS))
            val event = events.single()
            assertEquals("integrated", event["engine"])
            if (withModel) assertEquals("ready", event["type"])
            else {
                assertEquals("speech_fallback_model_missing", event["code"])
                assertEquals(true, event["canDownload"])
            }
            assertFalse(events.any { it["type"] == "listening" || it["type"] == "partial" })
        } finally {
            instrumentation.runOnMainSync { bridge?.dispose(); activity?.finish() }
            root.deleteRecursively()
        }
    }

    @Test fun missingPhoneRecognizerOffersAppManagedSetupWithoutRecording() = fallbackPreparation(false)
    @Test fun missingPhoneRecognizerUsesInstalledOfflineModelWithoutRecording() = fallbackPreparation(true)

    @Test fun releaseBeforeAudioActivationReturnsNoSpeechWithoutOpeningTheMic() {
        val root = root()
        val worker = Executors.newSingleThreadExecutor()
        val gate = CountDownLatch(1)
        worker.execute { gate.await(10, TimeUnit.SECONDS) }
        val completed = CountDownLatch(1)
        var result = ""
        val engine = OfflineSpeechEngine(instrumentation.targetContext, root, worker)
        try {
            instrumentation.runOnMainSync {
                engine.start("es-ES") { type, _, code -> result = "$type:$code"; completed.countDown() }
                engine.stop()
            }
            gate.countDown()
            assertTrue(completed.await(10, TimeUnit.SECONDS))
            assertEquals("error:speech_no_speech", result)
        } finally {
            gate.countDown()
            instrumentation.runOnMainSync { engine.dispose() }
            worker.awaitTermination(10, TimeUnit.SECONDS)
            root.deleteRecursively()
        }
    }
}
