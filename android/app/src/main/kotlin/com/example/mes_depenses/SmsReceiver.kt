package com.example.mes_depenses

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log

class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "MesDepenses"

        // Callback statique vers Flutter (rempli par MainActivity)
        var onSmsReceived: ((String, String) -> Unit)? = null
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        try {
            if (intent == null) return
            if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return

            for (message in messages) {
                val expediteur = message.originatingAddress ?: ""
                val corps = message.messageBody ?: ""

                // Filtrer : ne garder que Wave et Orange Money
                if (!_estSmsInteressant(expediteur, corps)) continue

                Log.d(TAG, "SMS reçu de $expediteur : $corps")

                // Envoyer à Flutter
                onSmsReceived?.invoke(expediteur, corps)
            }

        } catch (e: Exception) {
            Log.e(TAG, "Erreur onReceive SMS", e)
        }
    }

    private fun _estSmsInteressant(expediteur: String, corps: String): Boolean {
        val exp = expediteur.lowercase()
        val txt = corps.lowercase()

        // Wave
        if (exp.contains("wave") || txt.contains("wave") || txt.contains("wdf")) {
            return true
        }

        // Orange Money
        if (exp.contains("orange") ||
            txt.contains("ofms") ||
            txt.contains("orange money") ||
            txt.contains("orangemoney")
        ) {
            return true
        }

        return false
    }
}