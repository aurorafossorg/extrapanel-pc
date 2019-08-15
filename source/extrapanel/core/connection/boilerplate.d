module extrapanel.core.connection.boilerplate;

import extrapanel.core.plugin.info : PluginInfo;

abstract class ConnectionBackend {
	abstract void startup();
	abstract void cleanup();

	abstract void queue(PluginInfo pInfo);
	abstract void send();
	abstract void receive();

	abstract void onEvent(PluginInfo pInfo);
package:
	PluginInfo[] messageQueue;
}