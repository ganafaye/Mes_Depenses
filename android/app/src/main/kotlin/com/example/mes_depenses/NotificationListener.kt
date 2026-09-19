package com.example.mes_depenses

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class NotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "MesDepenses"
        const val CHANNEL = "mes_depenses/notifications"
        const val EVENT_CHANNEL = "mes_depenses/notifications_stream"

        // Callback statique vers Flutter (rempli par MainActivity)
        var onNotificationReceived: ((String, String, String) -> Unit)? = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        try {
            if (sbn == null) return

            val packageName = sbn.packageName ?: return
            val notification = sbn.notification ?: return
            val extras = notification.extras ?: return

            val titre = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
            val contenu = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
            val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
            val texteComplet = if (bigText.isNotEmpty()) bigText else contenu

            // Filtrer : ne garder que Wave et Orange Money
            if (!_estNotifInteressante(packageName, titre, texteComplet)) return

            Log.d(TAG, "Notif reçue de $packageName : $titre | $texteComplet")

            // Envoyer à Flutter
            onNotificationReceived?.invoke(packageName, titre, texteComplet)

        } catch (e: Exception) {
            Log.e(TAG, "Erreur onNotificationPosted", e)
        }
    }

    private fun _estNotifInteressante(
        packageName: String,
        titre: String,
        contenu: String,
    ): Boolean {
        val pkg = packageName.lowercase()
        val txt = (titre + " " + contenu).lowercase()

        // Wave
        if (pkg.contains("wave") || txt.contains("wave") || txt.contains("wdf")) {
            return true
        }

        // Orange Money
        if (pkg.contains("orange") || txt.contains("orange money") || txt.contains("ofms")) {
            return true
        }

        return false
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationListener connecté")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "NotificationListener déconnecté")
    }
}