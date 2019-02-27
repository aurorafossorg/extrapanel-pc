module extrapanel.config;

import util.paths;
import util.logger;

import std.net.curl;
import std.file;
import std.stdio;
import std.array;
import std.string;
import std.conv;

import core.stdc.stdlib;

public static enum Options : string {
	DeviceUUID 			= "device-uuid",
	LoadOnBoot 			= "launch-at-startup",
	CommDelay			= "comm-delay",
	WiFiEnabled			= "wifi-enabled",
	BluetoothEnabled	= "bluetooth-enabled",
	UsbEnabled			= "usb-enabled"
}

public static shared class Configuration {

	static void load() {
		if(!exists(appConfigPath ~ CONFIG_PATH) || hasArg("--reconfigure")) {
			firstTime = true;
			logger.info("No existing configuration file, creating one...");
			populate();
		}

		logger.info("Loading " ~ appConfigPath ~ CONFIG_PATH);
		cfgFile = File(appConfigPath ~ CONFIG_PATH, "r+");

		while(!cfgFile.eof) {
			parseConfig(cfgFile.readln(), metaOptions);
		}

		cfgFile.close();
	}

	static bool loadPlugin(string id, string path) {
		if(!exists(path)) {
			logger.critical("No existing configuration file for plugin", id, "! Make sure the plugin was installed properly!");
			return false;
		}

		logger.info("Loading " ~ path);
		File pluginFile = File(path, "r+");

		while(!pluginFile.eof) {
			string source = pluginFile.readln();
			pluginOptions[id] = string[string].init;
			parseConfig(source, pluginOptions[id]);
		}

		pluginFile.close();
		logger.info("Finished loading ", path, "config file");
		return true;
	}

	static void save() {
		if(changed) {
			cfgFile = File(appConfigPath ~ CONFIG_PATH, "w");
			foreach(string s; metaOptions.keys) {
				cfgFile.writeln(s ~ ": " ~ metaOptions[s]);
			}

			cfgFile.close();
		}
	}

	static T getPluginOption(T)(string id, string data) {
		return to!(T)(pluginOptions[id][data]);
	}

	static T getOption(T)(string data) {
		return to!(T)(metaOptions[data]);
	}

	static void setOption(T)(string op, T data) {
		changed = true;
		metaOptions[op] = to!string(data);
	}

	static void setPluginOption(T)(string id, string op, T data) {
		changed = true;
		pluginOptions[id][op] = to!string(data);
	}

	static string parsePlugin(string id) {
		string parsedConfig;
		logger.info("Parsing config options for plugin ", id);
		foreach(opt ; pluginOptions[id].keys) {
			logger.trace(opt, ": ", pluginOptions[id][opt]);
			parsedConfig ~= opt ~ ": " ~ pluginOptions[id][opt] ~ ";";
		}

		return parsedConfig;
	}

	static bool hasArg(string arg) {
		foreach(string s; appArgs)
			if(s == arg)
				return true;
		
		return false;
	}

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

		cfgFile.close();
	}

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