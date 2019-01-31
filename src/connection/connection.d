module extrapanel.connection;

import plugin.plugin : PluginInfo;

abstract class ConnectionBackend {
	abstract void queue(PluginInfo pInfo);
	abstract void send();
	abstract void receive();

	abstract void onEvent(PluginInfo pInfo);
package:
	PluginInfo[] messageQueue;
}