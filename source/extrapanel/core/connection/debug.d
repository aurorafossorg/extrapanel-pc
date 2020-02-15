module extrapanel.core.connection._debug;

// Extra Panel
import extrapanel.core.connection.boilerplate;
import extrapanel.core.plugin.info;

// STD
import std.stdio;

/**
 * debug backend.
 *
 * This is the connection backend implemented with a debug file/socket.
 */
class DebugBackend : ConnectionBackend {
	override {
		void startup() {}
		void cleanup() {}
		void queue(PluginInfo pInfo) {}
		void send() {}
		void receive() {}
		void onEvent(PluginInfo pInfo) {}
	}
}
