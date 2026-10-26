package hev.htproxy;

/**
 * JNI binding for hev-socks5-tunnel. The class name and method signatures must stay
 * exactly like this: the native library registers them by name.
 */
public class TProxyService {
    static {
        System.loadLibrary("hev-socks5-tunnel");
    }

    public static native void TProxyStartService(String configPath, int fd);

    public static native void TProxyStopService();

    /** [txPackets, txBytes, rxPackets, rxBytes] */
    public static native long[] TProxyGetStats();
}
