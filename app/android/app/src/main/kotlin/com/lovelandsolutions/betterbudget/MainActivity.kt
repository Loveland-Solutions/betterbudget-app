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
        // A bank file sent from another app (ReceiveFileActivity, #531).
        val incoming = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "betterbudget/incoming")
        incoming.setMethodCallHandler { call, result ->
            if (call.method == "take") result.success(IncomingFile.take()) else result.notImplemented()
        }
        IncomingFile.onArrived = { incoming.invokeMethod("arrived", null) }
        secretChannel(flutterEngine)
        // Android's version for Report a problem… (lib/data/report_problem.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "betterbudget/system")
            .setMethodCallHandler { call, result ->
                if (call.method == "release") result.success(android.os.Build.VERSION.RELEASE)
                else result.notImplemented()
            }
    }

    // A secret (the recovery key) copied marked sensitive, so Android 13+ keeps
    // it out of the copy preview and the keyboard's clipboard history.
    private fun secretChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "betterbudget/secret")
            .setMethodCallHandler { call, result ->
                val clipboard = getSystemService(android.content.Context.CLIPBOARD_SERVICE)
                    as android.content.ClipboardManager
                val text: String = call.argument("text") ?: ""
                when (call.method) {
                    "copy" -> {
                        val clip = android.content.ClipData.newPlainText("", text)
                        if (android.os.Build.VERSION.SDK_INT >= 33) {
                            clip.description.extras = android.os.PersistableBundle().apply {
                                putBoolean(android.content.ClipDescription.EXTRA_IS_SENSITIVE, true)
                            }
                        }
                        clipboard.setPrimaryClip(clip)
                        result.success(null)
                    }
                    // Only if what is there is still the key.
                    "clear" -> {
                        val now = clipboard.primaryClip?.getItemAt(0)?.text?.toString()
                        if (now == text) {
                            if (android.os.Build.VERSION.SDK_INT >= 28) clipboard.clearPrimaryClip()
                            else clipboard.setPrimaryClip(android.content.ClipData.newPlainText("", ""))
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        IncomingFile.onArrived = null
        super.cleanUpFlutterEngine(flutterEngine)
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
            // When the file was last changed, without fetching it.
            "changed" -> background(result) {
                val folder = Uri.parse(call.argument<String>("folder")!!)
                refresh(folder)
                find(folder, call.argument("name")!!)?.changed
            }
            // When and how big, for a look that compares one with the next.
            "stat" -> background(result) {
                val folder = Uri.parse(call.argument<String>("folder")!!)
                refresh(folder)
                find(folder, call.argument("name")!!)?.let {
                    mapOf("changed" to it.changed, "size" to it.size)
                }
            }
            // The names of the files in the folder, not its sub-folders.
            "list" -> background(result) {
                val folder = Uri.parse(call.argument<String>("folder")!!)
                refresh(folder)
                list(folder)
            }
            "delete" -> background(result) {
                delete(Uri.parse(call.argument("folder")!!), call.argument("name")!!)
                null
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
        val found = find(folder, name) ?: return null
        val doc = DocumentsContract.buildDocumentUriUsingTree(folder, found.id)
        val bytes = contentResolver.openInputStream(doc)!!.use { it.readBytes() }
        return mapOf("bytes" to bytes, "changed" to found.changed)
    }

    // The phone's own entries, for the computer: written over the file of
    // that name, or as a new file the first time.
    private fun write(folder: Uri, name: String, bytes: ByteArray) {
        val found = find(folder, name)?.id
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

    // Drive answers from a listing it keeps, which can be minutes old: ask it
    // to look again first.
    private fun refresh(folder: Uri) {
        try {
            contentResolver.refresh(
                DocumentsContract.buildChildDocumentsUriUsingTree(
                    folder,
                    DocumentsContract.getTreeDocumentId(folder),
                ),
                null,
                null,
            )
        } catch (e: Exception) {
            // A provider that can't refresh still answers.
        }
    }

    private class Found(val id: String, val changed: Long?, val size: Long?)

    private fun children(folder: Uri) = DocumentsContract.buildChildDocumentsUriUsingTree(
        folder,
        DocumentsContract.getTreeDocumentId(folder),
    )

    private val columns = arrayOf(
        DocumentsContract.Document.COLUMN_DOCUMENT_ID,
        DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        DocumentsContract.Document.COLUMN_SIZE,
        DocumentsContract.Document.COLUMN_MIME_TYPE,
    )

    // The names of the files in the folder (a sub-folder is not one).
    private fun list(folder: Uri): List<String> {
        val names = mutableListOf<String>()
        contentResolver.query(children(folder), columns, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                if (c.getString(4) != DocumentsContract.Document.MIME_TYPE_DIR) names.add(c.getString(1))
            }
        }
        return names
    }

    // Every file called [name]: Drive allows two of one name.
    private fun delete(folder: Uri, name: String) {
        val ids = mutableListOf<String>()
        contentResolver.query(children(folder), columns, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                if (c.getString(1) == name) ids.add(c.getString(0))
            }
        }
        for (id in ids) {
            DocumentsContract.deleteDocument(
                contentResolver,
                DocumentsContract.buildDocumentUriUsingTree(folder, id),
            )
        }
    }

    // The newest file called [name] in the folder, and when it was changed.
    private fun find(folder: Uri, name: String): Found? {
        var id: String? = null
        var changed: Long? = null
        var size: Long? = null
        contentResolver.query(children(folder), columns, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                // Drive allows two files of one name: the newest is the ledger.
                val at = if (c.isNull(2)) null else c.getLong(2)
                if (c.getString(1) == name && (id == null || (at ?: 0) > (changed ?: 0))) {
                    id = c.getString(0)
                    changed = at
                    size = if (c.isNull(3)) null else c.getLong(3)
                }
            }
        }
        val found = id ?: return null
        return Found(found, changed, size)
    }
}
