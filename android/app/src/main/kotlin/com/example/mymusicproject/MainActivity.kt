package com.example.mymusicproject
import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.mymusicproject/mediastore"
    private val DELETE_REQUEST_CODE = 100
    private var pendingDeleteResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLocalSongs" -> {
                    val songs = getMediaStoreAudioFiles()
                    result.success(songs)
                }
                "deleteSong" -> {
                    val id = call.argument<String>("id")
                    deleteMediaStoreAudioFile(id, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
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

        // En Android 11+ (API 30+) utilizamos MediaStore.createDeleteRequest
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
                e.printStackTrace()
                result.success(false)
            }
        } else {
            // En Android 10 (API 29) capturamos la RecoverableSecurityException
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
                        ex.printStackTrace()
                        result.success(false)
                    }
                } else {
                    result.success(false)
                }
            } catch (e: Exception) {
                e.printStackTrace()
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