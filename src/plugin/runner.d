module plugin.runner;

import std.path;
import std.string;
import std.conv;
import std.file;

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
	this() {
		string[] plugins;
		foreach(string dir; dirEntries(buildPath(appConfigPath, PLUGIN_BASE_PATH), SpanMode.shallow)) {
			plugins ~= dir;
		}

		this(plugins);
	}

	this(string[] plugins) {
		// Performs initial setup of all plugins
		logger.info(plugins.length, " plugins supplied, activating them...");
		int loadedPlugins;
		foreach(plugin; plugins) {
			logger.info("[", plugin, "]");
			// Obtains config path for current plugin
			string path = pluginRootPath(plugin);
			logger.info(">\033[1;33m\t Path built: ", path, "\033[1;37m");
			if (!Configuration.loadPlugin(plugin, path.buildPath("config.cfg"))) {
				logger.critical(">\033[0;31m\t No existing configuration file for plugin", plugin, "! Make sure the plugin was installed properly!\033[1;37m");
				continue;
			}
			logger.info(">\033[1;33m\t Configuration loaded successfully.\033[1;37m");

			// Inits the Lua state for each plugin
			lua_State* lua = luaL_newstate();
			luaL_openlibs(lua);
			logger.info(">\033[1;33m\t Lua state created\033[1;37m");

			// Parses config for Lua
			string parsedConfig = Configuration.parsePlugin(plugin);
			logger.info(">\033[1;33m\t Configuration parsed successfully: ", parsedConfig, "\033[1;37m");

			// Loads Lua script and calls setup()
			if(luaL_dofile(lua, path.buildPath("main.lua").toStringz)) {
				logger.critical(">\033[0;31m\t Failed to load Lua script for ", plugin, "! Error: ", lua_tostring(lua, -1), "\033[1;37m");
				lua_close(lua);
				continue;
			}
			logger.info(">\033[1;33m\t Script loaded successfully\033[1;37m");

			// Push parsedConfig and calls setup
			lua_getglobal(lua, ("setup").toStringz);
			lua_pushstring(lua, parsedConfig.toStringz);

			if(lua_pcall(lua, 1, 0, 0)) {
				logger.critical(">\033[0;31m\t setup() call failed for plugin ", plugin, "! Error: ", lua_tostring(lua, -1), "\033[1;37m");
				lua_close(lua);
				continue;
			}
			logger.info(">\033[1;33m\t setup() executed successfully\033[1;37m");

			// Plugin loaded successfully
			logger.info(">\033[0;32m\t Plugin ", plugin, " has loaded successfully.\n\033[1;37m");
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
				logger.critical("[", plugin, "] query() call failed for plugin ", plugin, "! Error: ", lua_tostring(activePlugins[plugin], -1).fromStringz);
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