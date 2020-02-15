module extrapanel.core.connection.wifi;

// Extra Panel
import extrapanel.core.connection.boilerplate;
import extrapanel.core.plugin.info;

/**
 * Wifi backend.
 *
 * This is the connection backend implemented with Wifi.
 */
class WifiBackend : ConnectionBackend {
	override {
		void queue(PluginInfo pInfo) {}
		void send() {}
		void receive() {}
		void onEvent(PluginInfo pInfo) {}
	}
}
