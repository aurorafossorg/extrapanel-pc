module extrapanel.config;

import util.paths;

import std.net.curl;
import std.file;
import std.stdio;
import std.experimental.logger;
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
			info("No existing configuration file, creating one...");
			populate();
		}

		info("Loading " ~ appConfigPath ~ CONFIG_PATH);
		cfgFile = File(appConfigPath ~ CONFIG_PATH, "r+");

		int i;
		while(!cfgFile.eof) {
			i++;
			std.experimental.logger.trace(i);
			string[] text = chomp(cfgFile.readln()).split(": ");
			writeln(text);
			if(text != []) {
				string opt = text[0];
				string data = text[1];

				options[opt] = data;
			}
		}

		cfgFile.close();
	}

	static void save() {
		if(changed) {
			writeln("y");
			cfgFile = File(appConfigPath ~ CONFIG_PATH, "w");
			foreach(string s; options.keys) {
				cfgFile.writeln(s ~ ": " ~ options[s]);
			}

			cfgFile.close();
		}
	}

	static T getOption(T)(string data) {
		return to!(T)(options[data]);
	}

	static void setOption(T)(string op, T data) {
		changed = true;
		options[op] = to!string(data);
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
			error("Couldn't fetch an UUID! Make sure you have a working internet connection, this is only needed for first-time setup.");
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

		cfgFile.write(Options.DeviceUUID ~ ": " ~ uuid);

		cfgFile.writeln(Options.LoadOnBoot ~ ": false");
		cfgFile.writeln(Options.CommDelay ~ ": 0.1");
		cfgFile.writeln(Options.WiFiEnabled ~ ": true");
		cfgFile.writeln(Options.BluetoothEnabled ~ ": true");
		cfgFile.writeln(Options.UsbEnabled ~ ": true");

		cfgFile.close();
	}

	static File cfgFile;
	static bool firstTime = false, changed = false;
	static string[string] options;
}