package app.aether.aether_gui

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingStart: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "aether/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) = VpnBridge.attach(events)
            override fun onCancel(arguments: Any?) = VpnBridge.detach()
        })

        MethodChannel(messenger, "aether/vpn").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> start(
                    call.argument<List<String>>("args") ?: emptyList(),
                    call.argument<Int>("port") ?: 1819,
                    call.argument<Boolean>("mapdns") ?: true,
                    result,
                )
                "stop" -> {
                    startService(Intent(this, AetherVpnService::class.java).setAction(AetherVpnService.ACTION_STOP))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun start(args: List<String>, port: Int, mapdns: Boolean, result: MethodChannel.Result) {
        val intent = Intent(this, AetherVpnService::class.java)
            .setAction(AetherVpnService.ACTION_START)
            .putStringArrayListExtra("args", ArrayList(args))
            .putExtra("port", port)
            .putExtra("mapdns", mapdns)

        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission("android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED
        ) requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 7)

        val prepare = VpnService.prepare(this)
        if (prepare == null) {
            launch(intent); result.success(null)
        } else {
            pendingStart = intent; pendingResult = result
            @Suppress("DEPRECATION") startActivityForResult(prepare, REQ_VPN)
        }
    }

    private fun launch(i: Intent) {
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQ_VPN) return super.onActivityResult(requestCode, resultCode, data)
        val r = pendingResult; val i = pendingStart
        pendingResult = null; pendingStart = null
        if (resultCode == Activity.RESULT_OK && i != null) { launch(i); r?.success(null) }
        else r?.error("permission_denied", "اجازه‌ی ساخت VPN داده نشد.", null)
    }

    companion object { private const val REQ_VPN = 100 }
}
