package com.lovelandsolutions.betterbudget

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns

// A bank file sent to BetterBudget from another app (#531): Share or Open
// with from the bank's app, Files or mail. This shows nothing: it reads the
// file into memory while the sender's permission holds, hands it to the app
// (IncomingFile), and brings the app's own window forward, so a second copy
// of the app never opens inside the sender's task. Nothing is written.
class ReceiveFileActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = sentUri(intent)
        // Made again (the phone turned while a slow file was read): the
        // first one is already reading it.
        if (uri == null || savedInstanceState != null) {
            finish()
            return
        }
        Thread {
            val name = displayName(uri) ?: uri.lastPathSegment ?: "file"
            val bytes = try {
                contentResolver.openInputStream(uri)?.use { readCapped(it) }
            } catch (e: Throwable) {
                null
            }
            runOnUiThread {
                IncomingFile.put(name, bytes)
                startActivity(
                    Intent(this, MainActivity::class.java).addFlags(
                        // Not CLEAR_TOP: whatever is open over the app
                        // (a picker) stays.
                        Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP,
                    ),
                )
                finish()
            }
        }.start()
    }

    private fun sentUri(intent: Intent?): Uri? = when (intent?.action) {
        Intent.ACTION_VIEW -> intent.data
        Intent.ACTION_SEND ->
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
        else -> null
    }

    private fun displayName(uri: Uri): String? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst() && !c.isNull(0)) c.getString(0) else null }
    } catch (e: Throwable) {
        null
    }

    // No bank statement is this big; one that is is said unreadable.
    private fun readCapped(input: java.io.InputStream): ByteArray? {
        val limit = 64 shl 20
        val out = java.io.ByteArrayOutputStream()
        val buf = ByteArray(64 * 1024)
        while (true) {
            val n = input.read(buf)
            if (n < 0) break
            out.write(buf, 0, n)
            if (out.size() > limit) return null
        }
        return out.toByteArray()
    }
}

// The file between the two activities, in memory only, until the app's
// Dart side takes it ("take" on betterbudget/incoming).
object IncomingFile {
    private var pending: Map<String, Any?>? = null
    var onArrived: (() -> Unit)? = null

    fun put(name: String, bytes: ByteArray?) {
        pending = mapOf("name" to name, "bytes" to bytes)
        onArrived?.invoke()
    }

    fun take(): Map<String, Any?>? = pending.also { pending = null }
}
