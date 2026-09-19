package com.example.mes_depenses

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val METHOD_CHANNEL = "mes_depenses/notifications"
    private val EVENT_CHANNEL = "mes_depenses/notifications_stream"
    private val SMS_EVENT_CHANNEL = "mes_depenses/sms_stream"

    private val CHANNEL_ID = "mes_depenses_confirmation"
    private val CHANNEL_NAME = "Confirmations de détection"
    private val CHANNEL_DESC = "Notifications affichées quand une opération est détectée"
    private val NOTIF_ID = 1001
    private val SMS_PERMISSION_REQUEST = 2001

    private var eventSink: EventChannel.EventSink? = null
    private var smsEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal de méthodes (Flutter → Kotlin)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> {
                        result.success(isNotificationAccessGranted())
                    }
                    "openNotificationSettings" -> {
                        openNotificationSettings()
                        result.success(true)
                    }
                    "isServiceRunning" -> {
                        result.success(NotificationListener.onNotificationReceived != null)
                    }
                    "afficherConfirmation" -> {
                        val operateur = call.argument<String>("operateur") ?: "wave"
                        val type = call.argument<String>("type") ?: "depense"
                        afficherConfirmation(operateur, type)
                        result.success(true)
                    }
                    "isSmsPermissionGranted" -> {
                        result.success(isSmsPermissionGranted())
                    }
                    "requestSmsPermission" -> {
                        requestSmsPermission()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Canal d'événements (Kotlin → Flutter) — Notifications
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    NotificationListener.onNotificationReceived = { pkg, titre, contenu ->
                        runOnUiThread {
                            eventSink?.success(
                                mapOf(
                                    "package" to pkg,
                                    "titre" to titre,
                                    "contenu" to contenu,
                                )
                            )
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    NotificationListener.onNotificationReceived = null
                }
            })

        // Canal d'événements (Kotlin → Flutter) — SMS
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsEventSink = events
                    SmsReceiver.onSmsReceived = { expediteur, corps ->
                        runOnUiThread {
                            smsEventSink?.success(
                                mapOf(
                                    "expediteur" to expediteur,
                                    "contenu" to corps,
                                )
                            )
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    smsEventSink = null
                    SmsReceiver.onSmsReceived = null
                }
            })
    }

    // ==================== NOTIFICATION DE CONFIRMATION ====================

    private fun afficherConfirmation(operateur: String, type: String) {
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val canal = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = CHANNEL_DESC
                    setShowBadge(false)
                    enableVibration(false)
                    enableLights(false)
                    setSound(null, null)
                }
                manager.createNotificationChannel(canal)
            }

            val intent = packageManager.getLaunchIntentForPackage(packageName)
            intent?.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP

            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(this, 0, intent, pendingFlags)

            val operateurLabel = when (operateur) {
                "wave" -> "Wave"
                "orange_money" -> "Orange Money"
                else -> operateur
            }
            val typeLabel = when (type) {
                "depense" -> "Dépense"
                "revenu" -> "Revenu"
                else -> type
            }

            val notification = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setContentTitle("Opération enregistrée")
                .setContentText("$operateurLabel • $typeLabel")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setSilent(true)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .build()

            manager.notify(NOTIF_ID, notification)
            android.util.Log.d("MesDepenses", "Notif confirmation affichée : $operateurLabel • $typeLabel")

        } catch (e: Exception) {
            android.util.Log.e("MesDepenses", "Erreur afficherConfirmation", e)
        }
    }

    // ==================== PERMISSIONS ====================

    private fun isNotificationAccessGranted(): Boolean {
        val flat = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        return flat.contains(packageName)
    }

    private fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    // ==================== PERMISSION SMS ====================

    private fun isSmsPermissionGranted(): Boolean {
        val receive = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECEIVE_SMS
        ) == PackageManager.PERMISSION_GRANTED
        val read = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_SMS
        ) == PackageManager.PERMISSION_GRANTED
        return receive && read
    }

    private fun requestSmsPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(
                Manifest.permission.RECEIVE_SMS,
                Manifest.permission.READ_SMS
            ),
            SMS_PERMISSION_REQUEST
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQUEST) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            android.util.Log.d("MesDepenses", "SMS permission granted: $granted")
        }
    }
}