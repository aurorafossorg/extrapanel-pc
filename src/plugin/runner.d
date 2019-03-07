module extrapanel.runner;

import std.path;
import std.string;
import std.conv;

import riverd.lua.statfun;
import riverd.lua.types;

import plugin.plugin;
import util.paths;
import util.config;
import util.logger;

/**
 *	runner.d - Struct holding the Lua VM responsible for running plugins
 */

public class PluginRunner {
	this(string[] plugins) {
		// Performs initial setup of all plugins
		logger.info(plugins.length, " plugins supplied, activating them...");
		int loadedPlugins;
		foreach(plugin; plugins) {
			// Inits the Lua state for each plugin
			lua_State* lua = luaL_newstate();
			luaL_openlibs(lua);
			logger.info("[", plugin, "] Lua state created");
			

			// Obtains config path for current plugin
			string path = pluginRootPath(plugin);
			logger.trace("[", plugin, "] Path built: ", path);
			if (!Configuration.loadPlugin(plugin, buildPath(path, "config.cfg"))) {
				logger.critical("[", plugin, "] No existing configuration file for plugin", plugin, "! Make sure the plugin was installed properly!");
				lua_close(lua);
				continue;
			}
			logger.trace("[", plugin, "] Configuration loaded successfully.");

			// Parses config for Lua
			string parsedConfig = Configuration.parsePlugin(plugin);
			logger.trace("[", plugin, "] Configuration parsed successfully: ", parsedConfig);

			// Loads Lua script and calls setup()
			if(luaL_dofile(lua, buildPath(path, "main.lua").toStringz)) {
				logger.critical("[", plugin, "] Failed to load Lua script for ", plugin, "! Error: ", lua_tostring(lua, -1));
				lua_close(lua);
				continue;
			}
			logger.trace("[", plugin, "] Script loaded successfully");

			// Push parsedConfig and calls setup
			lua_getglobal(lua, ("setup").toStringz);
			lua_pushstring(lua, parsedConfig.toStringz);

			if(lua_pcall(lua, 1, 0, 0)) {
				logger.critical("[", plugin, "] setup() call failed for plugin ", plugin, "! Error: ", lua_tostring(lua, -1));
				lua_close(lua);
				continue;
			}
			logger.trace("[", plugin, "] setup() executed successfully");

			// Plugin loaded successfully
			logger.info("[", plugin, "] Plugin ", plugin, " has loaded successfully.");
			activePlugins[plugin] = lua;
			loadedPlugins++;
		}

		logger.info(loadedPlugins, " loaded successfully.");
	}

	~this() {
		// Closes all Lua states
		foreach(lua; activePlugins.values) {
			lua_close(lua);
		}
		logger.info("Lua states closed");
	}

	// Performs a query() call for each plugin
	string[] query() {
		string[] buffer;
		foreach(plugin; activePlugins.keys) {
			// Pushes the query() method on the stack
			lua_getglobal(activePlugins[plugin], ("query").toStringz);

			// Calls query()
			if(lua_pcall(activePlugins[plugin], 0, 1, 0)) {
				logger.critical("[", plugin, "] query() call failed for plugin ", plugin, "! Error: ", lua_tostring(activePlugins[plugin], -1));
				continue;
			}

			// Return query() result and empties stack (to prevent memleaks/stackoverflow)
			buffer ~= to!string(lua_tostring(activePlugins[plugin], -1).fromStringz);
			lua_settop(activePlugins[plugin], 0);
		}

		return buffer;
	}

	// Performs an update() call for a specific plugin
	void update(string plugin, string data) {
		// Pushes the update() method on the stack 
		lua_getglobal(activePlugins[plugin], ("update").toStringz);

		// Calls update()
		if(lua_pcall(activePlugins[plugin], 1, 0, 0)) {
				logger.critical("[", plugin, "] update() call failed for plugin ", plugin, "! Error: ", lua_tostring(activePlugins[plugin], -1));
		}
	}

private:
	lua_State*[string] activePlugins;
}