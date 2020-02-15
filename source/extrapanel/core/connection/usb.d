module extrapanel.core.connection.usb;

// Extra Panel
import extrapanel.core.connection.boilerplate;
import extrapanel.core.plugin.info;

/**
 * USB backend.
 *
 * This is the connection backend implemented with USB.
 */
class UsbBackend : ConnectionBackend {
	override {
		void queue(PluginInfo pInfo) {}
		void send() {}
		void receive() {}
		void onEvent(PluginInfo pInfo) {}
	}
}
