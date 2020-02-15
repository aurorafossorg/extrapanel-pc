module extrapanel.core.connection.boilerplate;

import extrapanel.core.plugin.info : PluginInfo;

/**
 * Base class for connection backends.
 *
 * This is the base class defining an abstract connection backend. Every
 * connection extends this class.
 */
abstract class ConnectionBackend {
	/// This initialized the connection backend
	abstract void startup();
	/// This finalizes the connection backend
	abstract void cleanup();

	/**
	 * Performs a queue for the requested plugin.
	 *
	 * Params:
	 *  pInfo = the PluginInfo to perform a queue with.
	 */
	abstract void queue(PluginInfo pInfo);
	/// Sends all the collected info to the client.
	abstract void send();
	/// Receives updated info from the client.
	abstract void receive();

	/// A callback to notify a plugin of a changed event.
	abstract void onEvent(PluginInfo pInfo);
package:
	PluginInfo[] messageQueue;
}
