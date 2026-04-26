package com.tapajosweb.goride_driver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onStart() {
        super.onStart()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java) ?: return

        // Deleta canais antigos para recriar com configurações corretas
        // Necessário quando importância foi alterada após primeira instalação
        listOf("goride_general", "goride_rides", "goride_chat").forEach {
            manager.deleteNotificationChannel(it)
        }

        // Canal do foreground service — LOW (sem som, obrigatório)
        manager.createNotificationChannel(
            NotificationChannel(
                "goride_foreground",
                "GoRide — Motorista ativo",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Serviço de localização em segundo plano"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
        )

        // Canal de corridas — MAX (acorda tela, toca som alto)
        manager.createNotificationChannel(
            NotificationChannel(
                "goride_rides",
                "Corridas GoRide",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "Novas corridas disponíveis"
                enableVibration(true)
                setShowBadge(true)
            }
        )

        // Canal de avisos — HIGH (aparece na barra com som)
        manager.createNotificationChannel(
            NotificationChannel(
                "goride_general",
                "Avisos GoRide",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alertas, promoções e informações"
                enableVibration(true)
                setShowBadge(true)
            }
        )

        // Canal de chat — DEFAULT
        manager.createNotificationChannel(
            NotificationChannel(
                "goride_chat",
                "Chat GoRide",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Mensagens de passageiros"
                setShowBadge(true)
            }
        )
    }
}