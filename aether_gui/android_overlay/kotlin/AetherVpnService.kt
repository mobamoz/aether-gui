package app.aether.aether_gui

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import hev.htproxy.TProxyService
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Runs the bundled Aether binary (local SOCKS5), then routes the whole device through it
 * with hev-socks5-tunnel on a VpnService TUN interface.
 */
class AetherVpnService : VpnService() {
    @Volatile private var running = false
    private var worker: Thread? = null
    private var process: Process? = null
    private var tun: ParcelFileDescriptor? = null
    private var tproxyStarted = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) { stopAll(); return START_NOT_STICKY }
        if (running) return START_NOT_STICKY

        startForegroundCompat()
        val args = intent?.getStringArrayListExtra("args") ?: arrayListOf()
        val port = intent?.getIntExtra("port", 1819) ?: 1819
        val mapdns = intent?.getBooleanExtra("mapdns", true) ?: true

        running = true
        worker = Thread { runTunnel(args, port, mapdns) }.also { it.name = "aether-worker"; it.start() }
        return START_NOT_STICKY
    }

    private fun runTunnel(args: List<String>, port: Int, mapdns: Boolean) {
        try {
            VpnBridge.setState("connecting")
            val bin = File(applicationInfo.nativeLibraryDir, "libaether.so")
            if (!bin.exists()) throw IllegalStateException("فایل اجرایی Aether داخل اپ پیدا نشد.")

            val pb = ProcessBuilder(listOf(bin.absolutePath) + args)
            pb.directory(filesDir)
            pb.redirectErrorStream(true)
            pb.environment()["HOME"] = filesDir.absolutePath
            pb.environment()["TMPDIR"] = cacheDir.absolutePath
            VpnBridge.log("[app] aether ${args.joinToString(" ")}")
            val p = pb.start()
            process = p
            p.outputStream.close() // no stdin: Aether must never wait on a prompt
            Thread {
                try { p.inputStream.bufferedReader().forEachLine { VpnBridge.log(stripAnsi(it)) } } catch (_: Exception) {}
            }.start()

            // Aether opens SOCKS5 only after the gateway passes real traffic.
            val deadline = System.currentTimeMillis() + 180_000
            while (running && !portOpen(port)) {
                if (!p.isAlive) throw IllegalStateException("Aether بسته شد (کد ${p.exitValue()}). لاگ را ببین.")
                if (System.currentTimeMillis() > deadline) throw IllegalStateException("مسیر قابل‌استفاده‌ای پیدا نشد. حالت اسکن یا پروتکل را عوض کن.")
                Thread.sleep(500)
            }
            if (!running) return

            startTun(port, mapdns)
            VpnBridge.setState("connected")

            var lastTx = 0L; var lastRx = 0L
            while (running) {
                Thread.sleep(1000)
                if (!p.isAlive) throw IllegalStateException("Aether به‌طور غیرمنتظره بسته شد. لاگ را ببین.")
                val s = try { TProxyService.TProxyGetStats() } catch (_: Throwable) { null }
                if (s != null && s.size >= 4) {
                    // tx = written to TUN (download), rx = read from TUN (upload)
                    VpnBridge.stats(s[3] - lastRx, s[1] - lastTx)
                    lastTx = s[1]; lastRx = s[3]
                }
            }
        } catch (_: InterruptedException) {
        } catch (e: Exception) {
            if (running) VpnBridge.setState("error", e.message ?: e.javaClass.simpleName)
        } finally {
            cleanup()
        }
    }

    private fun startTun(port: Int, mapdns: Boolean) {
        val b = Builder()
            .setSession("Aether")
            .setMtu(MTU)
            .addAddress("198.18.0.1", 32)
            .addAddress("fc00::1", 128)
            .addRoute("0.0.0.0", 0)
            .addRoute("::", 0)
            .addDnsServer(if (mapdns) "198.18.0.2" else "1.1.1.1")
        // Aether's own sockets must stay outside the tunnel or traffic loops.
        try { b.addDisallowedApplication(packageName) } catch (_: PackageManager.NameNotFoundException) {}

        val fd = b.establish() ?: throw IllegalStateException("اجازه‌ی VPN لغو شده است.")
        tun = fd

        val cfg = File(filesDir, "tunnel.yml")
        cfg.writeText(buildString {
            appendLine("tunnel:")
            appendLine("  mtu: $MTU")
            appendLine("  ipv4: 198.18.0.1")
            appendLine("  ipv6: 'fc00::1'")
            appendLine("socks5:")
            appendLine("  port: $port")
            appendLine("  address: 127.0.0.1")
            appendLine("  udp: 'udp'")
            if (mapdns) {
                appendLine("mapdns:")
                appendLine("  address: 198.18.0.2")
                appendLine("  port: 53")
                appendLine("  network: 100.64.0.0")
                appendLine("  netmask: 255.192.0.0")
                appendLine("  cache-size: 10000")
            }
            appendLine("misc:")
            appendLine("  task-stack-size: 81920")
            appendLine("  log-level: warn")
        })
        TProxyService.TProxyStartService(cfg.absolutePath, fd.fd)
        tproxyStarted = true
        VpnBridge.log("[app] tunnel up")
    }

    @Synchronized
    private fun cleanup() {
        running = false
        if (tproxyStarted) { try { TProxyService.TProxyStopService() } catch (_: Throwable) {}; tproxyStarted = false }
        try { tun?.close() } catch (_: Exception) {}
        tun = null
        process?.let { p -> p.destroy(); Thread { try { Thread.sleep(1500); if (p.isAlive) p.destroyForcibly() } catch (_: Exception) {} }.start() }
        process = null
        if (VpnBridge.state != "error") VpnBridge.setState("disconnected")
        VpnBridge.stats(0, 0)
        stopForeground(true)
        stopSelf()
    }

    private fun stopAll() {
        running = false
        val w = worker
        if (w != null && w.isAlive) w.interrupt() else cleanup()
    }

    override fun onRevoke() { stopAll() }
    override fun onDestroy() { running = false; cleanup(); super.onDestroy() }

    private fun portOpen(port: Int) = try {
        Socket().use { it.connect(InetSocketAddress("127.0.0.1", port), 400); true }
    } catch (_: Exception) { false }

    private fun stripAnsi(s: String) = s.replace(Regex("\u001B\\[[;\\d]*[A-Za-z]"), "")

    private fun startForegroundCompat() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26)
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "Aether", NotificationManager.IMPORTANCE_LOW))

        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val stop = PendingIntent.getService(
            this, 1, Intent(this, AetherVpnService::class.java).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE,
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        val n = builder
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentTitle("Aether")
            .setContentText("تونل فعال است")
            .setContentIntent(open)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(null, "قطع اتصال", stop).build())
            .build()
        if (Build.VERSION.SDK_INT >= 34) startForeground(1, n, 1024 /* SYSTEM_EXEMPTED */) else startForeground(1, n)
    }

    companion object {
        const val ACTION_START = "app.aether.START"
        const val ACTION_STOP = "app.aether.STOP"
        private const val CHANNEL = "aether"
        private const val MTU = 1500
    }
}
