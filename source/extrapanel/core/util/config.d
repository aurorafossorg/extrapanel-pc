module extrapanel.core.util.config;

// Extra Panel
import extrapanel.core.util.formatter;
import extrapanel.core.util.logger;
import extrapanel.core.util.paths;
import extrapanel.core.util.util;

// STD
import std.array;
import std.conv;
import std.stdio;
import std.string;
import std.typecons;
import std.traits;
import std.uuid;

/**
 *	config.d - Configuration framework for the application
 */

/// Enum with all the default options of the application.
public static immutable enum Options : Tuple!(string, string) {
	DeviceUUID 			= tuple("device-uuid", "null"),
	LoadOnBoot 			= tuple("launch-at-startup", "false"),
	CommDelay			= tuple("comm-delay", "0.1"),
	WiFiEnabled			= tuple("wifi-enabled", "true"),
	BluetoothEnabled	= tuple("bluetooth-enabled", "true"),
	UsbEnabled			= tuple("usb-enabled", "true"),
	AcceptedWizard		= tuple("accepted-wizard", "false")
}

/// Enum with all the args the app accepts.
public static immutable enum Args : string {
	RECONFIGURE = "--reconfigure",	// Force the app to regenereate the configuration file
	OVERWRITE = "--overwrite",		// Force the daemon to run even with a lock file present
	SILENT = "--silent",			// Disables any output from logger
	VERBOSE = "--verbose"			// Shows verbose information
}

/**
 * Class holding all the configuration logic of the application.
 */
public static shared class Configuration {
	/// Loads the configuration file to memory.
	static void load() {
		// If config doesn't exist or we need to --reconfigure, generate a clean config file
		if(!exists(buildPath(appConfigPath, CONFIG_PATH)) || hasArg(Args.RECONFIGURE)) {
			firstTime = true;
			info("No existing configuration file, creating one...");
			populate();
		}

		// Loads the cfgFile
		info("Loading " ~ buildPath(appConfigPath, CONFIG_PATH));
		cfgFile = File(buildPath(appConfigPath, CONFIG_PATH), "r+");

		// Parses each config
		while(!cfgFile.eof) {
			parseConfig(cfgFile.readln(), metaOptions);
		}

		// Detects if wizard was completed
		firstTime = !(getOption!(bool)(Options.AcceptedWizard));

		// Closes file
		cfgFile.close();
		info("Configuration loaded successfully");
	}

	/**
	 * Loads a plugin config file to memory.
	 *
	 * Params:
	 *  id = the plugin's id to load.
	 *
	 * Returns: true if loading was successful, false otherwise.
	 */
	static bool loadPlugin(string id) {
		// If the path doesn't exist the plugin wasn't installed properly
		string path = buildPath(pluginRootPath(id), "config.cfg");
		if(!exists(path)) {
			return false;
		}

		// Loads the plugin cfgFile
		trace("[", id ,"] ", consoleYellow("Loading " ~ path));
		File pluginFile = File(path, "r+");
		pluginOptions[id] = string[string].init;

		// Parses each config
		while(!pluginFile.eof) {
			parseConfig(pluginFile.readln(), pluginOptions[id]);
		}

		// Closes file
		pluginFile.close();
		trace("[", id ,"] ", consoleGreen("Finished loading config file"));
		return true;
	}

	/// Saves the configuration on memory to the file.
	static void save() {
		// Save only if config changed, for optimization
		if(changed) {
			cfgFile = File(buildPath(appConfigPath, CONFIG_PATH), "w");
			foreach(string s; metaOptions.keys) {
				cfgFile.writeln(s ~ ": " ~ metaOptions[s]);
			}

			cfgFile.close();
		}
	}

	/// Saves the plugin's configuration on memory to the file.
	static void savePlugin(string pluginId) {
		cfgFile = File(buildPath(pluginRootPath(pluginId), "config.cfg"), "w");
		foreach(string s; pluginOptions[pluginId].keys) {
			cfgFile.writeln(s ~ ": " ~ pluginOptions[pluginId][s]);
		}

		cfgFile.close();
	}

	/**
	 * Retrieves a plugin config.
	 *
	 * Params:
	 *  id = the plugin's id to access.
	 *		data = the data to retrieve.
	 *
	 * Returns: the configuration requested. If it doesn't exists, it equals to string.init.
	 */
	static T getPluginOption(T)(string id, string data) {
		return to!(T)(pluginOptions[id][data]);
	}

	/// ditto
	static T[] getPluginOption(T : T[])(string id, string data) {
		return isSomeString!(T[])
			? to!(T[])(pluginOptions[id][data])
			: stringToArray!(T)(pluginOptions[id][data]);
	}

	/**
	 * Retrieves a general config.
	 *
	 * Params:
	 *  data = the data to retrieve.
	 *
	 * Returns: the configuration requested. If it doesn't exists, it equals to string.init.
	 */
	static T getOption(T)(Options data) {
		return to!(T)(metaOptions[data[0]]);
	}

	/**
	 * Sets a plugin config.
	 *
	 * Params:
	 *  id = the plugin's id to access.
	 *		op = the plugin's option to modify.
	 *		data = the data to save.
	 */
	static void setPluginOption(T)(string id, string op, T data) {
		pluginOptions[id][op] = to!string(data);
	}

	/// ditto
	static void setPluginOption(T : T[])(string id, string op, T[] data) {
		if(isArray!T) {
			pluginOptions[id][op] = isSomeString!T
				? data.to!string
				: data.arrayToString;
		}
	}

	/**
	 * Sets a general config.
	 *
	 * Params:
	 *  op = the option to modify.
	 *		data = the data to save.
	 */
	static void setOption(T)(Options op, T data) {
		changed = true;
		metaOptions[op[0]] = to!string(data);
	}

	/**
	 * Parses a plugin configuration for Lua scripts.
	 *
	 * Params:
	 *  id = the plugin's id to parse the config.
	 *
	 * Returns: a string containing the plugin's info, suitable for Lua scripts.
	 */
	static string parsePlugin(string id) {
		string parsedConfig;
		trace("Parsing config options for plugin ", id);
		foreach(opt ; pluginOptions[id].keys) {
			parsedConfig ~= opt ~ ": " ~ pluginOptions[id][opt] ~ ";";
		}

		return parsedConfig;
	}

	/**
	 * Unparses a plugin configuration from Lua scripts.
	 *
	 * Params:
	 *  id = the plugin's id to unparse the config.
	 *		parsedConfig = the generated parsed config to extract.
	 */
	static void unparsePlugin(string id, string parsedConfig) {
		string[] formattedPlugin = chomp(parsedConfig, ";").split(";");
		trace("Unparsing config options for plugin ", id);
		foreach(line ; formattedPlugin) {
			string[] text = chomp(line).split(": ");
			pluginOptions[id][text[0]] = text[1];
		}
	}

	/**
	 * Returns if a given arg was passed.
	 *
	 * Params:
	 *  arg = the argument to check.
	 *
	 * Returns: true if that arg was given, false otherwise.
	 */
	static bool hasArg(Args arg) {
		foreach(string s; appArgs)
			if(s == arg)
				return true;

		return false;
	}

	/**
	 * Return a list of GTK friendly args.
	 *
	 * GTK will crash if we give him invalid arguments, for some reason.
	 *
	 * Returns: a string array of arguments without custom arguments from the app.
	 */
	static string[] getGTKFriendlyArgs() {
		string[] parsedArgs;
		foreach(arg; appArgs) {
			if(!(arg == Args.RECONFIGURE || arg == Args.OVERWRITE ||
				arg == Args.SILENT || arg == Args.VERBOSE))
				parsedArgs ~= arg;
		}

		return parsedArgs;
	}

	/**
	 * Returns if it's the first time the app was launched.
	 *
	 * Returns: true if it's the first time, false otherwise.
	 */
	static bool isFirstTime() {
		return firstTime;
	}

	/// The string array with the application arguments.
	static string[] appArgs;

private:
	// Creates a new config file
	static void populate() {
		try {
			createAppPaths();
		} catch(FileException e) {

		}

		cfgFile = File(buildPath(appConfigPath, CONFIG_PATH), "w");
		writeln(buildPath(appConfigPath, CONFIG_PATH));

		// Generates UUID
		string uuid = to!string(randomUUID());

		cfgFile.writeln(Options.DeviceUUID[0] ~ ": " ~ uuid);
		cfgFile.writeln(unparseOption(Options.LoadOnBoot));
		cfgFile.writeln(unparseOption(Options.CommDelay));
		cfgFile.writeln(unparseOption(Options.WiFiEnabled));
		cfgFile.writeln(unparseOption(Options.BluetoothEnabled));
		cfgFile.writeln(unparseOption(Options.UsbEnabled));
		cfgFile.writeln(unparseOption(Options.AcceptedWizard));

		cfgFile.close();
	}

	static string unparseOption(Options opt) {
		return opt[0] ~ ": " ~ opt[1];
	}

	// Parses one line of config
	static void parseConfig(string source, ref string[string] buffer) {
		// Detect comments
		if(source == [] || source[0] == '#')
			return;

		// Separates key from value
		string[] text = chomp(source).split(": ");
		if(text != []) {
			immutable string opt = text[0];
			immutable string data = text[1];

			buffer[opt] = data;
		}
	}

	static File cfgFile;
	static bool firstTime = false, changed = false;
	static string[string] metaOptions;
	static string[string][string] pluginOptions;
}

@("Config: bootstraping config file")
unittest {
	// Creates a blank config file
	Configuration.populate();

	// Asserts that file exists
	immutable string configFilePath = buildPath(appConfigPath(), CONFIG_PATH);
	assert(configFilePath.exists);

	// Opens both generated and correct file to compare them
	File configFile = File(configFilePath);
	File bootstrapFile = File(buildPath("tools", "example-files", "extrapanel-bootstrap-config.cfg"));

	// Assert an UUID was created
	immutable string generatedUUID = configFile.readln(), nullUUID = bootstrapFile.readln();
	assert(generatedUUID != nullUUID);

	// Assert every line from now on is an exact copy from the intended config file
	while(!configFile.eof) {
		assert(configFile.readln() == bootstrapFile.readln());
	}

	// Assert that the file has no more lines than it should
	assert(bootstrapFile.eof);
}

@("Config: unparsing options")
unittest {
	// Assert that a tuple ("device-uuid", "null") gets transformed to CFG format properly
	assert(Configuration.unparseOption(Options.DeviceUUID) == "device-uuid: null");
}

@("Config: load config file")
unittest {
	Configuration.load();

	// Assert config was loaded
	assert(!Configuration.metaOptions.empty);

	// Assert it's first time config
	assert(Configuration.isFirstTime());

	// Assert the file is closed, meaning the config is stored on memory
	assert(!Configuration.cfgFile.isOpen());
}

@("Config: parsing config files")
unittest {
	immutable string configLine = "key: value\n";
	string[string] buffer;
	Configuration.parseConfig(configLine, buffer);

	assert(buffer["key"] == "value");
}

@("Config: saving config files")
unittest {
	Configuration.load();

	// Assert configuration is intact
	assert(!Configuration.changed);

	// Simulate UUID change and check if it's not null
	immutable string originalUUID = Configuration.getOption!(string)(Options.DeviceUUID);
	assert(originalUUID != "null");

	Configuration.setOption!(string)(Options.DeviceUUID, "null");
	assert(Configuration.getOption!(string)(Options.DeviceUUID) != originalUUID);
	assert(Configuration.changed);

	// Restore the UUID and simulate saving
	Configuration.setOption!(string)(Options.DeviceUUID, originalUUID);
	assert(Configuration.changed);

	Configuration.save();
}

@("Config: load a plugin config")
unittest {
	createAppPaths();
	immutable string pluginRoot = pluginRootPath("plugin-example");

	// Copy the CFG file to plugin path
	if(!exists(pluginRoot)) mkdir(pluginRoot);
	copy(buildPath(EXAMPLE_PLUGIN_PATH, "default.cfg"), buildPath(pluginRoot, "default.cfg"));
	copy(buildPath(EXAMPLE_PLUGIN_PATH, "config.cfg"), buildPath(pluginRoot, "config.cfg"));

	// Load the plugin config
	Configuration.loadPlugin("plugin-example");

	// Assert config was loaded
	assert(!Configuration.pluginOptions["plugin-example"].empty);

	// Assert configs are correct
	assert(Configuration.getPluginOption!(string)("plugin-example", "option-string") == "string");
	assert(Configuration.getPluginOption!(int)("plugin-example", "option-int") == 300);
	assert(Configuration.getPluginOption!(bool)("plugin-example", "option-bool") == false);
	assert(Configuration.getPluginOption!(float[])("plugin-example", "option-float-arr") == [3.1f, 4.5f, 0.2f]);
	assert(Configuration.getPluginOption!(string[])("plugin-example", "option-str-arr") == ["str1", "another string", "yay"]);

	// Assert config file and default file are the same
	auto configData = read(buildPath(pluginRoot, "config.cfg"));
	auto defaultData = read(buildPath(pluginRoot, "default.cfg"));

	assert(configData == defaultData);
}

@("Config: parse plugin config for Lua")
unittest {
	createAppPaths();
	immutable string pluginRoot = pluginRootPath("plugin-example");

	// Copy the CFG file to plugin path
	if(!exists(pluginRoot)) mkdir(pluginRoot);
	copy(buildPath(EXAMPLE_PLUGIN_PATH, "default.cfg"), buildPath(pluginRoot, "default.cfg"));
	copy(buildPath(EXAMPLE_PLUGIN_PATH, "config.cfg"), buildPath(pluginRoot, "config.cfg"));

	// Load the plugin config
	Configuration.loadPlugin("plugin-example");

	// Assert config was loaded
	assert(!Configuration.pluginOptions["plugin-example"].empty);

	// Assert plugin parsing is working
	immutable string parsedConfig = Configuration.parsePlugin("plugin-example");
	log(parsedConfig);
	assert(parsedConfig == "option-int: 300;option-float-arr: 3.1, 4.5, 0.2;option-string: string;option-bool: false;option-str-arr: str1, another string, yay;");
}

@("Config: unparse config from Lua")
unittest {
	createAppPaths();
	immutable string pluginRoot = pluginRootPath("plugin-example");

	// Copy the CFG file to plugin path
	if(!exists(pluginRoot)) mkdir(pluginRoot);
	copy(buildPath(EXAMPLE_PLUGIN_PATH, "default.cfg"), buildPath(pluginRoot, "default.cfg"));
	copy(buildPath(EXAMPLE_PLUGIN_PATH, "config.cfg"), buildPath(pluginRoot, "config.cfg"));

	// Load the plugin config
	Configuration.loadPlugin("plugin-example");

	// Unparse a config from Lua
	immutable string parsedConfig = "option-string: newString;option-int: 200;option-bool: true;option-float-arr: 3.14, 0.9;option-str-arr: less, string;";
	Configuration.unparsePlugin("plugin-example", parsedConfig);

	// Assert new configs were extracted
	assert(Configuration.getPluginOption!(string)("plugin-example", "option-string") == "newString");
	assert(Configuration.getPluginOption!(int)("plugin-example", "option-int") == 200);
	assert(Configuration.getPluginOption!(bool)("plugin-example", "option-bool") == true);
	assert(Configuration.getPluginOption!(float[])("plugin-example", "option-float-arr") == [3.14f, 0.9f]);
	assert(Configuration.getPluginOption!(string[])("plugin-example", "option-str-arr") == ["less", "string"]);
}

@("Config: saving a plugin config")
unittest {
	createAppPaths();
	immutable string pluginRoot = pluginRootPath("plugin-example");

	// Copy the CFG file to plugin path
	if(!exists(pluginRoot)) mkdir(pluginRoot);
	copy(buildPath(EXAMPLE_PLUGIN_PATH, "default.cfg"), buildPath(pluginRoot, "default.cfg"));
	copy(buildPath(EXAMPLE_PLUGIN_PATH, "config.cfg"), buildPath(pluginRoot, "config.cfg"));

	// Load the plugin config
	Configuration.loadPlugin("plugin-example");

	// Unparse a config from Lua
	//immutable string parsedConfig = "option-string: newString;option-int: 200;option-bool: true;";
	//Configuration.unparsePlugin("plugin-example", parsedConfig);
	// Changes some settings
	Configuration.setPluginOption!(string)("plugin-example", "option-string", "newString");
	Configuration.setPluginOption!(int)("plugin-example", "option-int", 200);
	Configuration.setPluginOption!(bool)("plugin-example", "option-bool", true);
	Configuration.setPluginOption!(float[])("plugin-example", "option-float-arr", [3.14f, 0.9f]);
	Configuration.setPluginOption!(string[])("plugin-example", "option-str-arr", ["less", "string"]);

	// Saves the configuration
	Configuration.savePlugin("plugin-example");

	// Assert config has changed
	auto originalCfg = read(buildPath(pluginRoot, "default.cfg"));
	auto changedCfg = read(buildPath(pluginRoot, "config.cfg"));

	assert(originalCfg != changedCfg);
}

@("Config: remove custom args")
unittest {
	string[] args = ["--overwrite", "--gtk-arg"];
	Configuration.appArgs = args;

	string[] friendlyArgs = Configuration.getGTKFriendlyArgs();

	// Assert unfriendly args have been removed
	assert(friendlyArgs == ["--gtk-arg"]);
	assert(args != friendlyArgs);
}

@("Config: get args")
unittest {
	Configuration.appArgs ~= Args.OVERWRITE;

	assert(Configuration.hasArg(Args.OVERWRITE));
	assert(!Configuration.hasArg(Args.RECONFIGURE));
}
