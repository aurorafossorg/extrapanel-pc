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

public class PluginRunner {
	this(string[] plugins) {
		// Loads Lua
		lua = luaL_newstate();
		luaL_openlibs(lua);
		logger.info("Lua state created");

		// Performs initial setup of all plugins
		this.activePlugins = plugins;
		logger.info(activePlugins.length, " active plugins, activating them...");
		int loadedPlugins;
		foreach(plugin; plugins) {
			// Obtains config path for current plugin
			string path = pluginRootPath(plugin);
			logger.trace("path built: ", path);
			logger.trace("config path: ", buildPath(path, "config.cfg"));
			if (!Configuration.loadPlugin(plugin, buildPath(path, "config.cfg"))) {
				logger.critical("No existing configuration file for plugin", plugin, "! Make sure the plugin was installed properly!");
				continue;
			}
			logger.trace("Configuration loaded successfully.");

			// Parses config for Lua
			string parsedConfig = Configuration.parsePlugin(plugin);
			logger.trace("Configuration parsed successfully: ", parsedConfig);

			// Loads Lua script and calls setup()
			if(luaL_loadfile(lua, buildPath(path, "main.lua").toStringz)) {
				logger.critical("Failed to load Lua script for ", plugin, "!");
				continue;
			}
			logger.trace("Script loaded successfully");

			// Prime Lua script
			if(lua_pcall(lua, 0, 0, 0)) {
				logger.critical("Failed to prime Lua script for plugin ", plugin, "!");
				continue;
			}
			logger.trace("Script primed successfully");

			// Push parsedConfig and calls setup
			lua_getglobal(lua, (plugin ~ "_setup").toStringz);
			lua_pushstring(lua, parsedConfig.toStringz);

			if(lua_pcall(lua, 1, 0, 0)) {
				logger.critical("setup() call failed for plugin ", plugin, "!");
				continue;
			}

			logger.info("Plugin ", plugin, " has loaded successfully.");
			loadedPlugins++;
		}

		logger.info(loadedPlugins, " loaded successfully.");
	}

	~this() {
		lua_close(lua);
		logger.info("Lua state closed");
	}

	string[] query() {
		string[] buffer;
		foreach(plugin; activePlugins) {
			lua_getglobal(lua, (plugin ~ "_query").toStringz);

			if(lua_pcall(lua, 0, 1, 0)) {
				logger.critical("query() call failed for plugin ", plugin, "!");
				continue;
			}

			buffer ~= to!string(lua_tostring(lua, -1).fromStringz);
		}

		return buffer;
	}

	void update(string plugin, string data) {
		lua_getglobal(lua, (plugin ~ "_update").toStringz);

		if(lua_pcall(lua, 1, 0, 0)) {
				logger.critical("update() call failed for plugin ", plugin, "!");
		}
	}

private:
	lua_State* lua;
	string[] activePlugins;
}