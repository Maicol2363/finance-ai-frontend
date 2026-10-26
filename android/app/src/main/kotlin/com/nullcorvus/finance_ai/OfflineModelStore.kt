package com.nullcorvus.finance_ai

import java.io.File
import java.io.IOException
import java.net.URL
import java.security.MessageDigest
import java.util.zip.ZipInputStream
import javax.net.ssl.HttpsURLConnection

internal data class OfflineModelSpec(val language: String, val name: String, val sha256: String) {
    val url: String get() = "https://alphacephei.com/vosk/models/$name.zip"
}

/** Only these immutable public model archives may be fetched. No audio enters this store. */
internal class OfflineModelStore(private val root: File) {
    companion object {
        val spanish = OfflineModelSpec("es-ES", "vosk-model-small-es-0.42",
            "09b239888f633ef2f0b4e09736e3d9936acfd810bc65d53fad45261762c6511f")
        val english = OfflineModelSpec("en-US", "vosk-model-small-en-us-0.15",
            "30f26242c4eb449f948e42cb302dd7a686cb29a3423a8367f99ff41780942498")
        fun spec(language: String) = when (language) {
            "es-ES" -> spanish
            "en-US" -> english
            else -> throw IOException("unsupported_language")
        }
        private const val MAX_ARCHIVE = 128L * 1024 * 1024
        private const val MAX_EXPANDED = 256L * 1024 * 1024

        fun extractionTarget(staging: File, name: String, model: OfflineModelSpec): File {
            if (!name.startsWith("${model.name}/") || name.contains('\\') ||
                name.split('/').any { it == ".." }) throw IOException("invalid_archive")
            val target = File(staging, name).canonicalFile
            if (!target.path.startsWith(staging.canonicalPath + File.separator)) {
                throw IOException("invalid_archive")
            }
            return target
        }
    }

    fun directory(model: OfflineModelSpec) = File(root, model.name)
    fun invalidate(model: OfflineModelSpec) { File(directory(model), ".verified").delete() }
    fun installed(model: OfflineModelSpec): Boolean {
        val directory = directory(model)
        return try {
            File(directory, ".verified").readText() == model.sha256 &&
                File(directory, "am/final.mdl").isFile && File(directory, "conf/model.conf").isFile
        } catch (_: IOException) { false }
    }

    fun download(model: OfflineModelSpec, cancelled: () -> Boolean,
                 progress: (String, Int?) -> Unit,
                 connected: (HttpsURLConnection?) -> Unit = {}) {
        if (installed(model)) return
        root.mkdirs()
        val archive = File(root, "${model.name}.download")
        var connection: HttpsURLConnection? = null
        try {
            connection = URL(model.url).openConnection() as HttpsURLConnection
            connected(connection)
            if (cancelled()) throw IOException("cancelled")
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 15_000
            connection.readTimeout = 30_000
            if (connection.responseCode != 200) throw IOException("download_failed")
            val length = connection.contentLengthLong
            if (length > MAX_ARCHIVE) throw IOException("archive_too_large")
            var downloaded = 0L
            var lastPercent = -2
            connection.inputStream.use { input ->
                archive.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        if (cancelled()) throw IOException("cancelled")
                        val count = input.read(buffer)
                        if (count < 0) break
                        downloaded += count
                        if (downloaded > MAX_ARCHIVE) throw IOException("archive_too_large")
                        output.write(buffer, 0, count)
                        val percent = if (length > 0) ((100 * downloaded / length).toInt()).coerceIn(0, 100) else -1
                        if (percent != lastPercent) {
                            lastPercent = percent
                            progress("downloading", percent.takeIf { it >= 0 })
                        }
                    }
                }
            }
            progress("installing", null)
            install(model, archive, cancelled)
        } finally {
            connection?.disconnect()
            connected(null)
            archive.delete()
        }
    }

    fun install(model: OfflineModelSpec, archive: File, cancelled: () -> Boolean = { false }) {
        if (archive.length() > MAX_ARCHIVE) throw IOException("archive_too_large")
        val digest = MessageDigest.getInstance("SHA-256")
        archive.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                if (cancelled()) throw IOException("cancelled")
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        val hash = digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
        if (hash != model.sha256) throw IOException("integrity_failed")
        val staging = File(root, "${model.name}.staging")
        try {
            if (staging.exists()) staging.deleteRecursively()
            staging.mkdirs()
            var expanded = 0L
            var entries = 0
            ZipInputStream(archive.inputStream().buffered()).use { zip ->
                while (true) {
                    if (cancelled()) throw IOException("cancelled")
                    val entry = zip.nextEntry ?: break
                    if (++entries > 1024) throw IOException("invalid_archive")
                    val target = extractionTarget(staging, entry.name, model)
                    if (entry.isDirectory) target.mkdirs() else {
                        target.parentFile!!.mkdirs()
                        target.outputStream().use { output ->
                            val buffer = ByteArray(64 * 1024)
                            while (true) {
                                if (cancelled()) throw IOException("cancelled")
                                val count = zip.read(buffer)
                                if (count < 0) break
                                expanded += count
                                if (expanded > MAX_EXPANDED) throw IOException("archive_too_large")
                                output.write(buffer, 0, count)
                            }
                        }
                    }
                    zip.closeEntry()
                }
            }
            val extracted = File(staging, model.name)
            if (!File(extracted, "am/final.mdl").isFile || !File(extracted, "conf/model.conf").isFile) {
                throw IOException("invalid_archive")
            }
            File(extracted, ".verified").writeText(model.sha256)
            if (cancelled()) throw IOException("cancelled")
            val destination = directory(model)
            if (destination.exists() && !destination.deleteRecursively()) throw IOException("install_failed")
            if (!extracted.renameTo(destination)) throw IOException("install_failed")
        } finally {
            staging.deleteRecursively()
        }
    }
}
