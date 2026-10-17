package com.nullcorvus.finance_ai

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.io.IOException
import java.security.MessageDigest
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class OfflineModelStoreTest {
    @get:Rule val temporary = TemporaryFolder()

    private fun fixture(vararg names: String): Pair<File, OfflineModelSpec> {
        val archive = temporary.newFile()
        ZipOutputStream(archive.outputStream()).use { zip ->
            for (name in names) {
                zip.putNextEntry(ZipEntry(name)); zip.write("fixture".toByteArray()); zip.closeEntry()
            }
        }
        val hash = MessageDigest.getInstance("SHA-256").digest(archive.readBytes())
            .joinToString("") { "%02x".format(it.toInt() and 255) }
        return archive to OfflineModelSpec("es-ES", "fixture", hash)
    }

    @Test fun verifiedArchiveIsInstalledOnlyWhenComplete() {
        val (archive, spec) = fixture("fixture/am/final.mdl", "fixture/conf/model.conf")
        val store = OfflineModelStore(temporary.newFolder())
        assertFalse(store.installed(spec))
        store.install(spec, archive)
        assertTrue(store.installed(spec))
        assertEquals(spec.sha256, File(store.directory(spec), ".verified").readText())
    }

    @Test fun corruptedArchiveCannotBecomeAnInstalledModel() {
        val (archive, spec) = fixture("fixture/am/final.mdl", "fixture/conf/model.conf")
        archive.appendText("tampered")
        val store = OfflineModelStore(temporary.newFolder())
        assertThrows(IOException::class.java) { store.install(spec, archive) }
        assertFalse(store.installed(spec))
    }

    @Test fun traversalAndUnexpectedRootsCannotWriteOutsideStaging() {
        val staging = temporary.newFolder()
        for (name in listOf("fixture/../../outside", "/fixture/file", "other/file", "fixture\\outside")) {
            assertThrows(IOException::class.java) {
                OfflineModelStore.extractionTarget(staging, name, OfflineModelStore.spanish.copy(name = "fixture"))
            }
        }
    }

    @Test fun incompleteAndCancelledModelsDoNotGetVerifiedMarkers() {
        val (archive, spec) = fixture("fixture/am/final.mdl")
        val root = temporary.newFolder()
        val store = OfflineModelStore(root)
        assertThrows(IOException::class.java) { store.install(spec, archive) }
        assertFalse(store.installed(spec))
        assertFalse(File(root, "fixture.staging").exists())
        assertThrows(IOException::class.java) { store.install(spec, archive) { true } }
        assertFalse(store.installed(spec))
    }

    @Test fun languageSelectionCannotSupplyArbitraryModelUrls() {
        assertEquals(OfflineModelStore.spanish, OfflineModelStore.spec("es-ES"))
        assertEquals(OfflineModelStore.english, OfflineModelStore.spec("en-US"))
        assertThrows(IOException::class.java) { OfflineModelStore.spec("https://private.invalid") }
    }
}
