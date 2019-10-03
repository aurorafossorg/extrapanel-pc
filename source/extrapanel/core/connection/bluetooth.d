module extrapanel.core.connection.bluetooth;

// Extra Panel
import extrapanel.core.connection.boilerplate;
import extrapanel.core.plugin.info;

/**
 * Bluetooth backend.
 *
 * This is the connection backend implemented with Bluetooth.
 */
class BluetoothBackend : ConnectionBackend {
	override {
		void queue(PluginInfo pInfo) {}
		void send() {}
		void receive() {}
		void onEvent(PluginInfo pInfo) {}
	}
}