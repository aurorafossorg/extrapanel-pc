module extrapanel.core.util.config;

import extrapanel.core.util.paths;
import extrapanel.core.util.logger;

import std.net.curl;
import std.file;
import std.path;
import std.stdio;
import std.array;
import std.string;
import std.conv;
import std.typecons;
import std.uuid;

import core.stdc.stdlib;

/**
 *	config.d - Configuration framework for the application
 */

// Default configs for the app
public static enum Options : Tuple!(string, string) {
	DeviceUUID 			= tuple("device-uuid", "null"),
	LoadOnBoot 			= tuple("launch-at-startup", "false"),
	CommDelay			= tuple("comm-delay", "0.1"),
	WiFiEnabled			= tuple("wifi-enabled", "true"),
	BluetoothEnabled	= tuple("bluetooth-enabled", "true"),
	UsbEnabled			= tuple("usb-enabled", "true"),
	AcceptedWizard		= tuple("accepted-wizard", "false")
}

public static shared class Configuration {

	// Loads the configuration
	static void load() {
		// If config doesn't exist or we need to --reconfigure, generate a clean config file
		if(!exists(appConfigPath ~ CONFIG_PATH) || hasArg("--reconfigure")) {
			firstTime = true;
			logger.info("No existing configuration file, creating one...");
			populate();
		}

		// Loads the cfgFile
		logger.info("Loading " ~ appConfigPath ~ CONFIG_PATH);
		cfgFile = File(appConfigPath ~ CONFIG_PATH, "r+");

		// Parses each config
		while(!cfgFile.eof) {
			parseConfig(cfgFile.readln(), metaOptions);
		}

		// Detects if wizard was completed
		firstTime = !(getOption!(bool)(Options.AcceptedWizard));

		// Closes file
		cfgFile.close();
		logger.info("Configuration loaded successfully");
	}

	// Load plugin config file
	static bool loadPlugin(string id) {
		// If the path doesn't exist the plugin wasn't installed properly
		string path = buildPath(pluginRootPath(id), "config.cfg");
		if(!exists(path)) {
			return false;
		}

		// Loads the plugin cfgFile
		logger.trace("Loading " ~ path);
		File pluginFile = File(path, "r+");
		pluginOptions[id] = string[string].init;

		// Parses each config
		while(!pluginFile.eof) {
			parseConfig(pluginFile.readln(), pluginOptions[id]);
		}

		// Closes file
		pluginFile.close();
		logger.trace("Finished loading ", id, "config file");
		return true;
	}

	// Saves the configuration
	static void save() {
		// Save only if config changed, for optimization
		if(changed) {
			cfgFile = File(appConfigPath ~ CONFIG_PATH, "w");
			foreach(string s; metaOptions.keys) {
				cfgFile.writeln(s ~ ": " ~ metaOptions[s]);
			}

			cfgFile.close();
		}
	}

	static void savePlugin() {

	}

	// Retrieves a plugin config
	static T getPluginOption(T)(string id, string data) {
		return to!(T)(pluginOptions[id][data]);
	}

	// Retrieves a general config
	static T getOption(T)(Options data) {
		return to!(T)(metaOptions[data[0]]);
	}

	// Sets a plugin config
	static void setPluginOption(T)(string id, string op, T data) {
		changed = true;
		pluginOptions[id][op] = to!string(data);
	}

	// Sets a general config
	static void setOption(T)(Options op, T data) {
		changed = true;
		metaOptions[op[0]] = to!string(data);
	}

	// Parses a plugin configuration for Lua scripts
	static string parsePlugin(string id) {
		string parsedConfig;
		logger.trace("Parsing config options for plugin ", id);
		foreach(opt ; pluginOptions[id].keys) {
			parsedConfig ~= opt ~ ": " ~ pluginOptions[id][opt] ~ ";";
		}

		return parsedConfig;
	}

	// Unparses a plugin configuration from Lua scripts
	static string[string] unparsePlugin(string id, string parsedConfig) {
		string formattedPlugin = parsedConfig.replace(";", "\n");
		logger.trace("Unparsing config options for plugin ", id);
		string[string] unparsedConfig;
		foreach(opt ; pluginOptions[id].keys) {
			unparsedConfig["a"] ~= opt ~ ": " ~ pluginOptions[id][opt] ~ ";";
		}

		return unparsedConfig;
	}

	// Returns if a given arg was passed
	static bool hasArg(string arg) {
		foreach(string s; appArgs)
			if(s == arg)
				return true;
		
		return false;
	}

	// Returns if it's the first time the app was launched
	static bool isFirstTime() {
		return firstTime;
	}

	static string[] appArgs;
	
private:
	// Creates a new config file
	static void populate() {
		try {
			createAppPaths();
		} catch(FileException e) {

		}

		cfgFile = File(appConfigPath ~ CONFIG_PATH, "w");
		writeln(appConfigPath ~ CONFIG_PATH);

		// Generates UUID
		//string uuid = retrieveUUID();
		string uuid = to!string(randomUUID());

		// We write() here instead of writeln() because retrieveUUID() returns a string with a new-line at the end
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
		logger.trace("Text is \"", text, "\"");
		if(text != []) {
			string opt = text[0];
			string data = text[1];

			buffer[opt] = data;
		}
	}

	static File cfgFile;
	static bool firstTime = false, changed = false;
	static string[string] metaOptions;
	static string[string][string] pluginOptions;
}