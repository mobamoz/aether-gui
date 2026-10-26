package app.aether.aether_gui

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/** Process-wide state shared between the VPN service and the Flutter UI. */
object VpnBridge {
    @Volatile var state: String = "disconnected"
    @Volatile var message: String = ""
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())
    private val logs = ArrayDeque<String>()

    fun attach(s: EventChannel.EventSink) {
        sink = s
        emit(mapOf("type" to "state", "state" to state, "message" to message))
        synchronized(logs) { logs.toList() }.forEach { emit(mapOf("type" to "log", "line" to it)) }
    }

    fun detach() { sink = null }

    fun setState(s: String, msg: String = "") {
        state = s; message = msg
        emit(mapOf("type" to "state", "state" to s, "message" to msg))
    }

    fun log(line: String) {
        synchronized(logs) { logs.addLast(line); while (logs.size > 500) logs.removeFirst() }
        emit(mapOf("type" to "log", "line" to line))
    }

    fun stats(up: Long, down: Long) = emit(mapOf("type" to "stats", "up" to up, "down" to down))

    private fun emit(m: Map<String, Any>) { main.post { sink?.success(m) } }
}
