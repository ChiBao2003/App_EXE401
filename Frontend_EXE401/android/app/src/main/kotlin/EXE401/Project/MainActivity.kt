package EXE401.Project

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val jsonRequestCode = 9042
    private val saveRequestCode = 9043
    private var jsonResult: MethodChannel.Result? = null
    private var saveContent: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register Usage Stats Platform Channel
        UsageStatsPlugin.registerWith(flutterEngine, applicationContext)
        // Register Screen Event EventChannel
        ScreenEventTracker.registerWith(flutterEngine, applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smarttime/json_document")
            .setMethodCallHandler { call, result ->
                if (call.method == "saveJson") {
                    if (jsonResult != null) {
                        result.error("busy", "A JSON document operation is already open", null)
                    } else {
                        val content = call.argument<String>("content")
                        val name = call.argument<String>("name") ?: "smarttime_design.json"
                        if (content == null || content.toByteArray(Charsets.UTF_8).size > 262144) {
                            result.error("size", "JSON exceeds 256 KB", null)
                        } else {
                            jsonResult = result
                            saveContent = content.toByteArray(Charsets.UTF_8)
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/json"
                                putExtra(Intent.EXTRA_TITLE, name)
                            }
                            try {
                                startActivityForResult(intent, saveRequestCode)
                            } catch (error: Exception) {
                                jsonResult = null
                                saveContent = null
                                result.error("save", error.message, null)
                            }
                        }
                    }
                } else if (call.method != "openJson") {
                    result.notImplemented()
                } else if (jsonResult != null) {
                    result.error("busy", "A JSON picker is already open", null)
                } else {
                    jsonResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain"))
                    }
                    try {
                        startActivityForResult(intent, jsonRequestCode)
                    } catch (error: Exception) {
                        jsonResult = null
                        result.error("picker", error.message, null)
                    }
                }
            }
    }

    @Deprecated("Android document picker callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != jsonRequestCode && requestCode != saveRequestCode) return
        val pending = jsonResult ?: return
        jsonResult = null
        if (requestCode == saveRequestCode) {
            val content = saveContent
            saveContent = null
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                pending.success(null)
                return
            }
            try {
                if (content == null) throw IllegalStateException("Missing JSON content")
                contentResolver.openOutputStream(data.data!!, "wt")?.use { output ->
                    output.write(content)
                    output.flush()
                } ?: throw IllegalStateException("Cannot write selected document")
                pending.success(data.data.toString())
            } catch (error: Exception) {
                pending.error("write", error.message, null)
            }
            return
        }
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.success(null)
            return
        }
        try {
            val bytes = contentResolver.openInputStream(data.data!!)?.use { input ->
                input.readBytes()
            } ?: throw IllegalStateException("Cannot read selected document")
            if (bytes.size > 262144) throw IllegalArgumentException("JSON exceeds 256 KB")
            pending.success(String(bytes, Charsets.UTF_8))
        } catch (error: Exception) {
            pending.error("read", error.message, null)
        }
    }
}
