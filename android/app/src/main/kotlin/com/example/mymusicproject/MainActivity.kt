package com.example.mymusicproject

import android.app.Activity
import android.app.ActivityManager
import android.content.ClipData
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.database.ContentObserver
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.mymusicproject/mediastore"
    private val DIAGNOSTICS_CHANNEL = "com.mymusicproject/diagnostics"
    private val EVENTS_CHANNEL = "com.mymusicproject/media_events"
    private val DELETE_REQUEST_CODE = 100
    private val TAG = "MainActivity"
    private var pendingDeleteResult: MethodChannel.Result? = null

    private var eventsChannel: MethodChannel? = null
    private var mediaObserver: ContentObserver? = null
    private val uiHandler = Handler(Looper.getMainLooper())
    private var debounce: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLocalSongs" -> {
                    val songs = getMediaStoreAudioFiles()
                    result.success(songs)
                }
                "deleteSong" -> {
                    val id = call.argument<String>("id")
                    deleteMediaStoreAudioFile(id, result)
                }
                "shareSong" -> {
                    val id = call.argument<String>("id")
                    val title = call.argument<String>("title") ?: ""
                    val artist = call.argument<String>("artist") ?: ""
                    val asFile = call.argument<Boolean>("asFile") ?: true
                    shareSong(id, title, artist, asFile, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(messenger, DIAGNOSTICS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "exitReasons" -> {
                        try {
                            result.success(getExitReasons())
                        } catch (e: Exception) {
                            Log.e(TAG, "Error al obtener exitReasons", e)
                            result.error("EXIT_REASONS_ERROR", e.message, Log.getStackTraceString(e))
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        eventsChannel = MethodChannel(messenger, EVENTS_CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanNew" -> scanNewAudioFiles(result)
                    else -> result.notImplemented()
                }
            }
        }
        registerMediaObserver()
    }

    override fun onDestroy() {
        mediaObserver?.let { contentResolver.unregisterContentObserver(it) }
        mediaObserver = null
        super.onDestroy()
    }
    private fun registerMediaObserver() {
        if (mediaObserver != null) return
        val observer = object : ContentObserver(uiHandler) {
            override fun onChange(selfChange: Boolean) {
                debounce?.let { uiHandler.removeCallbacks(it) }
                val task = Runnable { eventsChannel?.invokeMethod("mediaChanged", null) }
                debounce = task
                uiHandler.postDelayed(task, 600)
            }
        }
        contentResolver.registerContentObserver(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, true, observer
        )
        mediaObserver = observer
    }
    private fun scanNewAudioFiles(result: MethodChannel.Result) {
        Thread {
            try {
                val prefs = getSharedPreferences("media_scan", Context.MODE_PRIVATE)
                val last = prefs.getLong("last_scan", 0L) - 5000
                val now = System.currentTimeMillis()
                val exts = setOf("mp3", "m4a", "aac", "ogg", "opus", "flac", "wav", "wma")

                @Suppress("DEPRECATION")
                val roots = listOf(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
                )

                val found = mutableListOf<String>()
                fun walk(dir: File, depth: Int) {
                    if (depth > 4 || found.size >= 200) return
                    val files = dir.listFiles() ?: return
                    for (f in files) {
                        if (f.isDirectory) {
                            if (!f.name.startsWith(".")) walk(f, depth + 1)
                        } else if (f.lastModified() > last && f.extension.lowercase() in exts) {
                            found.add(f.absolutePath)
                        }
                    }
                }
                roots.forEach { walk(it, 0) }

                if (found.isNotEmpty()) {
                    val latch = CountDownLatch(found.size)
                    MediaScannerConnection.scanFile(
                        applicationContext, found.toTypedArray(), null
                    ) { _, _ -> latch.countDown() }
                    latch.await(4, TimeUnit.SECONDS)
                }
                prefs.edit().putLong("last_scan", now).apply()
                runOnUiThread { result.success(found.size) }
            } catch (e: Exception) {
                Log.e(TAG, "Error al escanear audios nuevos", e)
                runOnUiThread { result.success(0) }
            }
        }.start()
    }
    private fun shareSong(
        id: String?,
        title: String,
        artist: String,
        asFile: Boolean,
        result: MethodChannel.Result
    ) {
        try {
            val label = if (artist.isBlank()) title else "$title - $artist"
            val intent = Intent(Intent.ACTION_SEND)
            if (asFile && id != null) {
                val uri = ContentUris.withAppendedId(
                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id.toLong()
                )
                intent.type = "audio/*"
                intent.putExtra(Intent.EXTRA_STREAM, uri)
                intent.putExtra(Intent.EXTRA_TITLE, label)
                intent.clipData = ClipData.newRawUri(label, uri)
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } else {
                intent.type = "text/plain"
                intent.putExtra(Intent.EXTRA_TEXT, label)
            }
            val chooser = Intent.createChooser(intent, "Compartir")
            startActivity(chooser)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error al compartir", e)
            result.error("SHARE_ERROR", e.message, null)
        }
    }
    private fun getExitReasons(): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return emptyList()
        }
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val reasons = am.getHistoricalProcessExitReasons(packageName, 0, 20)
        return reasons.map { exitInfo ->
            mapOf(
                "reason" to exitInfo.reason,
                "time" to exitInfo.timestamp,
                "description" to (exitInfo.description ?: "")
            )
        }
    }

    private fun getMediaStoreAudioFiles(): List<Map<String, Any>> {
        val songList = mutableListOf<Map<String, Any>>()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DURATION
        )

        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"

        contentResolver.query(collection, projection, selection, null, sortOrder)?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val dataColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                val title = cursor.getString(titleColumn) ?: "Desconocido"
                val artist = cursor.getString(artistColumn) ?: "Artista desconocido"
                val data = cursor.getString(dataColumn) ?: ""
                val duration = cursor.getLong(durationColumn)

                val songMap = mapOf(
                    "id" to id.toString(),
                    "title" to title,
                    "artist" to artist,
                    "data" to data,
                    "duration" to duration
                )
                songList.add(songMap)
            }
        }
        return songList
    }

    private fun deleteMediaStoreAudioFile(id: String?, result: MethodChannel.Result) {
        if (id == null) {
            result.success(false)
            return
        }
        val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id.toLong())

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val uris = listOf(uri)
                val pendingIntent = MediaStore.createDeleteRequest(contentResolver, uris)
                pendingDeleteResult = result
                startIntentSenderForResult(
                    pendingIntent.intentSender,
                    DELETE_REQUEST_CODE,
                    null, 0, 0, 0, null
                )
            } catch (e: Exception) {
                Log.e(TAG, "Error al eliminar archivo en Android 11+", e)
                result.success(false)
            }
        } else {
            try {
                val rowsDeleted = contentResolver.delete(uri, null, null)
                result.success(rowsDeleted > 0)
            } catch (e: android.app.RecoverableSecurityException) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    pendingDeleteResult = result
                    try {
                        startIntentSenderForResult(
                            e.userAction.actionIntent.intentSender,
                            DELETE_REQUEST_CODE,
                            null, 0, 0, 0, null
                        )
                    } catch (ex: Exception) {
                        Log.e(TAG, "Error en RecoverableSecurityException", ex)
                        result.success(false)
                    }
                } else {
                    result.success(false)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error al eliminar archivo en Android 10-", e)
                result.success(false)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == DELETE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                pendingDeleteResult?.success(true)
            } else {
                pendingDeleteResult?.success(false)
            }
            pendingDeleteResult = null
        }
    }
}