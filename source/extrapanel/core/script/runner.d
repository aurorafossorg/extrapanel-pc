module extrapanel.core.script.runner;

// Extra Panel
import extrapanel.core.plugin.info;
import extrapanel.core.util.config;
import extrapanel.core.util.exception;
import extrapanel.core.util.formatter;
import extrapanel.core.util.logger;
import extrapanel.core.util.paths;

// GTK
import gtk.c.types;

// RiverD
import riverd.lua.statfun;
import riverd.lua.types;

// STD
import std.conv;
import std.exception;
import std.string;

/// Enum that represents the type of scripts being used.
public enum ScriptType : byte {
	PLUGIN_SCRIPT,
	CONFIG_SCRIPT
}

/**
 * Singleton to manage the loading, running and cleanup of external scripts.
 */
public class ScriptRunner {
public:
	static ScriptRunner getInstance() {
		if(this.scriptRunner is null)
			this.scriptRunner = new ScriptRunner();

		return this.scriptRunner;
	}

	/**
	 * Loads a plugin into memory.
	 *
	 * Params:
	 *  pluginId = the plugin's id to load
	 *		scriptType = the script that's being loaded. Defaults to PLUGIN_SCRIPT.
	 */
	void loadPlugin(string pluginId, ScriptType scriptType = ScriptType.PLUGIN_SCRIPT) {
		trace("[", pluginId, "] Loading script...");

		// Get the root path of the plugin's files
		string pluginPath = pluginRootPath(pluginId);

		// Load the plugin config
		Configuration.loadPlugin(pluginId);

		// Creates a lua_State
		lua_State* lua = luaL_newstate();
		luaL_openlibs(lua);
		trace("[", pluginId, "]", consoleYellow("\tLua state created"));

		// Loads the script file
		string luaFile;
		switch(scriptType) {
			case ScriptType.PLUGIN_SCRIPT:
				luaFile = buildPath(pluginPath, "main.lua");
				break;
			case ScriptType.CONFIG_SCRIPT:
				luaFile = buildPath(pluginPath, "ui.lua");
				break;
			default:
				break;
		}

		// If the file doesn't exists throw an exception
		if(!exists(luaFile)) {
			trace("[", pluginId, "]", consoleRed("\tScript file not found!"));
			lua_close(lua);
			throw new FileNotFoundException(luaFile);
		}

		// Loads the script to the lua_State
		if(luaL_loadfile(lua, luaFile.toStringz)) {
			throw new ScriptLoadingException(pluginId);
		}

		// If we're loading a plugin, we'll need to already run some methods at this stage
		if(scriptType == ScriptType.PLUGIN_SCRIPT) {
			string parsedConfig = Configuration.parsePlugin(pluginId);

			// Run the file to get the global symbols
			runLuaCommand(lua_pcall(lua, 0, LUA_MULTRET, 0), lua, pluginId, "main");

			// Passes the config and calls setup
			lua_getglobal(lua, ("setup").toStringz);
			lua_pushstring(lua, parsedConfig.toStringz);
			runLuaCommand(lua_pcall(lua, 1, 0, 0), lua, pluginId, "setup");
		}

		// Lua state created successfully, and script loaded
		trace("[", pluginId, "]", consoleGreen("\tScript loaded successfully"));
		pluginScripts[pluginId][scriptType] = lua;
	}

	/**
	 * Removes a plugin from memory
	 *
	 * Params:
	 *  pluginId = the plugin's id to unload.
	 */
	void removePlugin(string pluginId) {
		if(pluginId in pluginScripts) {
			trace("ScriptRunner: plugin \"", pluginId, "\" being removed");
			foreach(scriptType; pluginScripts[pluginId].byKey()) {
				// If it's a config script, we need to save possibly updated configs.
				if(scriptType == ScriptType.CONFIG_SCRIPT) {
					lua_State* lua = pluginScripts[pluginId][scriptType];

					lua_getglobal(lua, ("saveConfig").toStringz);
					runLuaCommand(lua_pcall(lua, 0, 1, 0), lua, pluginId, "saveConfig");
					string parsedConfig = to!(string)(lua_tostring(lua, -1).fromStringz);
					Configuration.unparsePlugin(pluginId, parsedConfig);
					Configuration.savePlugin(pluginId);
				}
				lua_close(pluginScripts[pluginId][scriptType]);
				//pluginScripts[pluginId].remove(scriptType);
			}

			pluginScripts.remove(pluginId);
		}
	}

	/**
	 * Cleans up all the loaded plugins.
	 *
	 * This needs to be called specifically, because a destructor is @nogc and cleanup steps may
	 * save configuration, which causes memory exceptions.
	 */
	void cleanup() {
		foreach(pluginId; pluginScripts.byKey())
				removePlugin(pluginId);
	}

	/**
	 * Sets up a configuration panel for a plugin.
	 *
	 * Params:
	 *  pluginId = the plugin's id to set up.
	 *
	 * Returns: a GtkBox* object. This will always be a valid object even if no custom UI exists.
	 */
	GtkBox* setupConfigMenu(string pluginId) {
		// Finds the lua_State
		lua_State* lua = pluginScripts[pluginId][ScriptType.CONFIG_SCRIPT];
		if(lua is null) {
			critical("Error: no lua script for config menu for \"", pluginId, "\"");
			return null;
		}

		// We'll need to pass the path to the configMenu.ui to the lua script
		string pluginPath = pluginRootPath(pluginId);
		string uiFile = buildPath(pluginPath, "configMenu.ui");
		lua_pushstring(lua, uiFile.toStringz);

		// We'll call the script now
		runLuaCommand(lua_pcall(lua, 1, LUA_MULTRET, 0), lua, pluginId, "main");

		// Retrieve the constructed GtkBox*
		GtkBox* configBox = cast(GtkBox*) lua_touserdata(lua, -1);

		// Loads saved configuration
		string parsedConfig = Configuration.parsePlugin(pluginId);
		lua_getglobal(lua, ("loadConfig").toStringz);
		lua_pushstring(lua, parsedConfig.toStringz);
		runLuaCommand(lua_pcall(lua, 1, 0, 0), lua, pluginId, "main");
		lua_settop(lua, 0);

		trace("[", pluginId, "] Config passed successfully");

		return configBox;
	}

	/**
	 * Runs a query call on a plugin.
	 *
	 * Params:
	 *  pluginId = the plugin's id to query.
	 *
	 * Returns: result from the query.
	 */
	string runQuery(string pluginId) {
		// Finds the lua_State
		lua_State* lua = pluginScripts[pluginId][ScriptType.PLUGIN_SCRIPT];
		if(lua is null) {
			critical("Error: no lua script for config menu for \"", pluginId, "\"");
			return null;
		}

		// Pushes the query() method on the stack
		lua_getglobal(lua, ("query").toStringz);

		// Calls query()
		if(lua_pcall(lua, 0, 1, 0)) {
			critical("[", pluginId, "] query() call failed for plugin ", pluginId, "! Error: ",
					lua_tostring(lua, -1).fromStringz);
			return "";
		}

		// Return query() result and empties stack (to prevent memleaks/stackoverflow)
		string result = to!string(lua_tostring(lua, -1).fromStringz);
		lua_settop(lua, 0);

		return result;
	}

private:
	this() {}

	void runLuaCommand(int errCode, lua_State* lua, string pluginId, string method) {
		if(errCode) {
			critical("[", pluginId, "] Failed to pass config to Lua script for ", pluginId,
			"! Error: ", lua_tostring(lua, -1).fromStringz);
			lua_close(lua);
			throw new ScriptMethodExecutionException(pluginId, method);
		}
	}

	static ScriptRunner scriptRunner;
	lua_State*[ScriptType][string] pluginScripts;
}

@("Script: ensure singleton")
unittest {
	ScriptRunner runner;

	assert(runner is null);

	runner = ScriptRunner.getInstance();
	assert(!(runner is null));

	ScriptRunner runner2 = ScriptRunner.getInstance();
	assert(runner == runner2);
}

@("Script: test a plugin script")
unittest {
	Configuration.load();
	createAppPaths();

	ScriptRunner scriptRunner = ScriptRunner.getInstance();

	string pluginRoot = pluginRootPath("plugin-example");

	// Copy the script file to plugin path
	if(!exists(pluginRoot)) mkdir(pluginRoot);
	copy(buildPath(EXAMPLE_PLUGIN_PATH, "main.lua"), buildPath(pluginRoot, "main.lua"));
	copy(buildPath(EXAMPLE_PLUGIN_PATH, "config.cfg"), buildPath(pluginRoot, "config.cfg"));

	// Assert loading a plugin works. This also ensure Lua ran the script's setup() method
	scriptRunner.loadPlugin("plugin-example");
	assert(!scriptRunner.pluginScripts.empty);

	// Assert a query can be made and is equal to "example"
	assert(scriptRunner.runQuery("plugin-example") == "example");

	// Assert that script runner throws an exception for a non existing script
	assertThrown!FileNotFoundException(scriptRunner.loadPlugin("non-existing-plugin"));

	// Assert that "plugin-example" has no UI script
	assertThrown!FileNotFoundException(scriptRunner.loadPlugin("plugin-example", ScriptType.CONFIG_SCRIPT));

	// Remove the plugin and assert it doesn't exist in memory
	scriptRunner.removePlugin("plugin-example");
	assert(!("plugin-example" in scriptRunner.pluginScripts));
}
