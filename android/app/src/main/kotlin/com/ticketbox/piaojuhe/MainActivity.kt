package com.ticketbox.piaojuhe

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OCR_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "recognizeImageText" -> {
                    val imagePath = call.argument<String>("imagePath")
                    if (imagePath.isNullOrBlank()) {
                        result.error("invalid-image", "Missing image path.", null)
                        return@setMethodCallHandler
                    }

                    recognizeImageText(imagePath, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun recognizeImageText(
        imagePath: String,
        result: MethodChannel.Result,
    ) {
        val imageFile = File(imagePath)
        if (!imageFile.exists()) {
            result.error("file-not-found", "Image file not found.", null)
            return
        }

        val inputImage = try {
            InputImage.fromFilePath(applicationContext, Uri.fromFile(imageFile))
        } catch (_: Exception) {
            result.error("invalid-image", "Image file could not be opened.", null)
            return
        }

        val recognizer = TextRecognition.getClient(
            ChineseTextRecognizerOptions.Builder().build(),
        )

        recognizer.process(inputImage)
            .addOnSuccessListener { recognizedText ->
                val text = recognizedText.text.trim()
                if (text.isEmpty()) {
                    result.error("no-text", "No text recognized.", null)
                } else {
                    result.success(text)
                }
            }
            .addOnFailureListener { error ->
                result.error("ocr-failed", error.message, null)
            }
            .addOnCompleteListener {
                recognizer.close()
            }
    }

    companion object {
        private const val OCR_CHANNEL = "com.ticketbox.piaojuhe/ticket_ocr"
    }
}
