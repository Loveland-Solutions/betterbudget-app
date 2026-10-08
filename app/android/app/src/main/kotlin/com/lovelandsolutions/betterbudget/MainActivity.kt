package com.lovelandsolutions.betterbudget

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// The folder the ledger was moved to (ADR 0005), reached through Android's own
// folder picker, which is how the app reads a Google Drive or OneDrive folder
// without touching the network itself. `lib/data/phone_ledger.dart` calls this.
class MainActivity : FlutterActivity() {
    private val pickRequest = 4711
    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "betterbudget/folder")
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> {
                // A picker already open answers its caller with nothing.
                pendingPick?.success(null)
                pendingPick = result
                startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), pickRequest)
            }
            // The newest folder the phone still lets the app read.
            "kept" -> result.success(
                contentResolver.persistedUriPermissions
                    .filter { it.isReadPermission }
                    .maxByOrNull { it.persistedTime }
                    ?.uri?.toString(),
            )
            "read" -> background(result) {
                read(Uri.parse(call.argument("folder")!!), call.argument("name")!!)
            }
            "write" -> background(result) {
                write(
                    Uri.parse(call.argument("folder")!!),
                    call.argument("name")!!,
                    call.argument<ByteArray>("bytes")!!,
                )
                null
            }
            "forget" -> {
                val uri = Uri.parse(call.argument<String>("folder")!!)
                val held = contentResolver.persistedUriPermissions.firstOrNull { it.uri == uri }
                if (held != null) {
                    val flags = (if (held.isReadPermission) Intent.FLAG_GRANT_READ_URI_PERMISSION else 0) or
                        (if (held.isWritePermission) Intent.FLAG_GRANT_WRITE_URI_PERMISSION else 0)
                    contentResolver.releasePersistableUriPermission(uri, flags)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // A cloud folder's provider may go to the network, so never on the UI thread.
    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            try {
                val value = work()
                runOnUiThread { result.success(value) }
            } catch (e: Throwable) {
                runOnUiThread { result.error(e.javaClass.simpleName, e.message, null) }
            }
        }.start()
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return
        val result = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            // Read and write: the phone's own entries will be written here too.
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            result.success(uri.toString())
        } catch (e: Throwable) {
            result.error(e.javaClass.simpleName, e.message, uri.toString())
        }
    }

    private fun read(folder: Uri, name: String): Map<String, Any?>? {
        val (found, changed) = find(folder, name) ?: return null
        val doc = DocumentsContract.buildDocumentUriUsingTree(folder, found)
        val bytes = contentResolver.openInputStream(doc)!!.use { it.readBytes() }
        return mapOf("bytes" to bytes, "changed" to changed)
    }

    // The phone's own entries, for the computer: written over the file of
    // that name, or as a new file the first time.
    private fun write(folder: Uri, name: String, bytes: ByteArray) {
        val found = find(folder, name)?.first
        val doc = if (found != null) {
            DocumentsContract.buildDocumentUriUsingTree(folder, found)
        } else {
            DocumentsContract.createDocument(
                contentResolver,
                DocumentsContract.buildDocumentUriUsingTree(
                    folder,
                    DocumentsContract.getTreeDocumentId(folder),
                ),
                "application/octet-stream",
                name,
            ) ?: throw IllegalStateException("The folder didn't take a new file")
        }
        // "wt" cuts the old file short first; a provider without it gets "w".
        val out = try {
            contentResolver.openOutputStream(doc, "wt")
        } catch (e: Exception) {
            contentResolver.openOutputStream(doc, "w")
        }
        out!!.use { it.write(bytes) }
    }

    // The newest file called [name] in the folder, and when it was changed.
    private fun find(folder: Uri, name: String): Pair<String, Long?>? {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(
            folder,
            DocumentsContract.getTreeDocumentId(folder),
        )
        var id: String? = null
        var changed: Long? = null
        contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            ),
            null,
            null,
            null,
        )?.use { c ->
            while (c.moveToNext()) {
                // Drive allows two files of one name: the newest is the ledger.
                val at = if (c.isNull(2)) null else c.getLong(2)
                if (c.getString(1) == name && (id == null || (at ?: 0) > (changed ?: 0))) {
                    id = c.getString(0)
                    changed = at
                }
            }
        }
        val found = id ?: return null
        return Pair(found, changed)
    }
}
