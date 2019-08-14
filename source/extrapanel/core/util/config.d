module extrapanel.core.util.config;

import extrapanel.core.util.paths;
import extrapanel.core.util.logger;

import std.net.curl;
import std.file;
import std.stdio;
import std.array;
import std.string;
import std.conv;

import core.stdc.stdlib;

/**
 *	config.d - Configuration framework for the application
 */

// Default configs for the app
public static enum Options : string {
	DeviceUUID 			= "device-uuid",
	LoadOnBoot 			= "launch-at-startup",
	CommDelay			= "comm-delay",
	WiFiEnabled			= "wifi-enabled",
	BluetoothEnabled	= "bluetooth-enabled",
	UsbEnabled			= "usb-enabled",
	AcceptedWizard		= "accepted-wizard"
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
	static bool loadPlugin(string id, string path) {
		// If the path doesn't exist the plugin wasn't installed properly
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
	static T getOption(T)(string data) {
		return to!(T)(metaOptions[data]);
	}

	// Sets a plugin config
	static void setPluginOption(T)(string id, string op, T data) {
		changed = true;
		pluginOptions[id][op] = to!string(data);
	}

	// Sets a general config
	static void setOption(T)(string op, T data) {
		changed = true;
		metaOptions[op] = to!string(data);
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

	// Retrieves an UUID through an online generator
	static string retrieveUUID() {
		try {
			return cast(string) get("https://www.uuidgenerator.net/api/version4");
		} catch(CurlException e) {
			logger.error("Couldn't fetch an UUID! Make sure you have a working internet connection, this is only needed for first-time setup.");
			return "null";
		}
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
		string uuid = retrieveUUID();

		// We write() here instead of writeln() because retrieveUUID() returns a string with a new-line at the end
		cfgFile.write(Options.DeviceUUID ~ ": " ~ uuid);

		cfgFile.writeln(Options.LoadOnBoot ~ ": false");
		cfgFile.writeln(Options.CommDelay ~ ": 0.1");
		cfgFile.writeln(Options.WiFiEnabled ~ ": true");
		cfgFile.writeln(Options.BluetoothEnabled ~ ": true");
		cfgFile.writeln(Options.UsbEnabled ~ ": true");
		cfgFile.writeln(Options.AcceptedWizard ~ ": false");

		cfgFile.close();
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