package com.omzakrevo.etikpro

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Bluetooth classique (SPP) pour les imprimantes thermiques.
 *
 * - Connexion avec 3 méthodes de repli (sécurisée, non sécurisée, canal RFCOMM 1),
 *   car beaucoup d'imprimantes refusent la connexion « sécurisée » standard.
 * - Envoi des données sans aucun octet ajouté (pas de retour à la ligne ni d'espace).
 * - L'état de connexion est lu sans rien écrire sur l'imprimante.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "etikpro/bt_classic"
    private val spp: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var socket: BluetoothSocket? = null
    private var out: OutputStream? = null
    private var connectedAddress: String? = null

    private fun adapter(): BluetoothAdapter? =
        (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
            ?: BluetoothAdapter.getDefaultAdapter()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            fun ok(v: Any?) = main.post { result.success(v) }
            fun err(code: String, msg: String?) = main.post { result.error(code, msg, null) }
            when (call.method) {
                "sdk" -> result.success(android.os.Build.VERSION.SDK_INT)
                "enabled" -> result.success(adapter()?.isEnabled == true)
                "paired" -> io.execute {
                    try { ok(paired()) } catch (e: SecurityException) { err("PERMISSION", e.message) }
                }
                "connect" -> {
                    val addr = call.argument<String>("address") ?: ""
                    io.execute {
                        try { ok(connect(addr)) } catch (e: SecurityException) { err("PERMISSION", e.message) }
                    }
                }
                "isConnected" -> result.success(socket?.isConnected == true && out != null)
                "connectedAddress" -> result.success(if (socket?.isConnected == true) connectedAddress else null)
                "write" -> {
                    val data = call.argument<ByteArray>("data")
                    val chunk = call.argument<Int>("chunk") ?: 1024
                    val delay = call.argument<Int>("delayMs") ?: 8
                    io.execute { ok(write(data, chunk, delay.toLong())) }
                }
                "disconnect" -> io.execute { close(); ok(true) }
                else -> result.notImplemented()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun paired(): List<Map<String, Any>> {
        val a = adapter() ?: return emptyList()
        return a.bondedDevices.map {
            val type = when (it.type) {
                BluetoothDevice.DEVICE_TYPE_LE -> "le"
                BluetoothDevice.DEVICE_TYPE_DUAL -> "dual"
                BluetoothDevice.DEVICE_TYPE_CLASSIC -> "classic"
                else -> "unknown"
            }
            mapOf("name" to (it.name ?: ""), "address" to it.address, "type" to type)
        }
    }

    @SuppressLint("MissingPermission")
    private fun connect(address: String): String? {
        val a = adapter() ?: return "Bluetooth indisponible sur ce téléphone."
        if (!a.isEnabled) return "Le Bluetooth est éteint."
        if (socket?.isConnected == true && connectedAddress == address && out != null) return null
        close()
        val device = try { a.getRemoteDevice(address) } catch (e: Exception) { return "Adresse d'imprimante invalide." }
        try { a.cancelDiscovery() } catch (_: Exception) {}

        val attempts = listOf<() -> BluetoothSocket>(
            { device.createRfcommSocketToServiceRecord(spp) },
            { device.createInsecureRfcommSocketToServiceRecord(spp) },
            {
                val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                m.invoke(device, 1) as BluetoothSocket
            },
            {
                val m = device.javaClass.getMethod("createInsecureRfcommSocket", Int::class.javaPrimitiveType)
                m.invoke(device, 1) as BluetoothSocket
            },
        )
        var last: String? = null
        for (make in attempts) {
            var s: BluetoothSocket? = null
            try {
                s = make()
                s.connect()
                if (s.isConnected) {
                    socket = s
                    out = s.outputStream
                    connectedAddress = address
                    return null
                }
            } catch (e: Exception) {
                last = e.message
                try { s?.close() } catch (_: Exception) {}
                try { Thread.sleep(300) } catch (_: Exception) {}
            }
        }
        return "Connexion impossible ($last). Vérifiez que l'imprimante est allumée, proche, " +
            "et qu'elle n'est pas connectée à un autre téléphone."
    }

    private fun write(data: ByteArray?, chunk: Int, delayMs: Long): String? {
        val o = out ?: return "Imprimante non connectée."
        if (data == null) return "Aucune donnée."
        return try {
            var off = 0
            while (off < data.size) {
                val end = minOf(off + chunk, data.size)
                o.write(data, off, end - off)
                o.flush()
                off = end
                if (delayMs > 0) Thread.sleep(delayMs)
            }
            null
        } catch (e: Exception) {
            close()
            "Envoi interrompu (${e.message}). Réessayez."
        }
    }

    private fun close() {
        try { out?.close() } catch (_: Exception) {}
        try { socket?.close() } catch (_: Exception) {}
        out = null
        socket = null
        connectedAddress = null
    }

    override fun onDestroy() {
        close()
        super.onDestroy()
    }
}
