module extrapanel.config;

import std.net.curl;
import std.file;
import std.stdio;
import std.experimental.logger;
import std.array;
import std.string;
import std.conv;
import core.stdc.stdlib;
import std.path;

public static immutable string FILE_PATH = "/.config/extrapanel/extrapanel.cfg";

public static enum Options : string {
	DeviceUUID 			= "device-uuid",
	LoadOnBoot 			= "launch-at-startup",
	CommDelay			= "comm-delay",
	WiFiEnabled			= "wifi-enabled",
	BluetoothEnabled	= "bluetooth-enabled",
	UsbEnabled			= "usb-enabled"
}

public static string rootPath() {
	return expandTilde("~");
}

public static shared class Configuration {

	static void load() {
		if(!loaded) {
			if(!exists(rootPath ~ FILE_PATH) || hasArg("--reconfigure")) {
				firstTime = true;
				info("No existing configuration file, creating one...");
				populate();
			}

			info("Loading " ~ rootPath ~ FILE_PATH);
			cfgFile = File(rootPath ~ FILE_PATH, "r+");

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

			loaded = true;
			cfgFile.close();
		}
	}

	static void save() {
		if(changed && loaded) {
			writeln("y");
			cfgFile = File(rootPath ~ FILE_PATH, "w");
			foreach(string s; options.keys) {
				cfgFile.writeln(s ~ ": " ~ options[s]);
			}

			cfgFile.close();
		}
	}

	static T getOption(T)(string data) {
		return loaded ? to!(T)(options[data]) : T.init;
	}

	static void setOption(T)(string op, T data) {
		changed = true;
		options[op] = loaded ? to!string(data) : T;
	}

	static bool hasArg(string arg) {
		foreach(string s; appArgs)
			if(s == arg)
				return true;
		
		return false;
	}

	static string[] appArgs;
	
private:
	static void populate() {
		try {
			mkdir(rootPath ~ "/.config/extrapanel");
			mkdir(rootPath ~ "/.config/extrapanel/plugins");
		} catch(FileException e) {

		}

		cfgFile = File(rootPath ~ FILE_PATH, "w");
		writeln(rootPath ~ FILE_PATH);

		// Generates UUID
		string uuid = "-1";
		try {
			uuid = cast(string) get("https://www.uuidgenerator.net/api/version4");
		} catch(CurlException e) {
			error("Couldn't fetch an UUID! Make sure you have a working internet connection, this is only needed for first-time setup.");
			return;
		}

		cfgFile.write(Options.DeviceUUID ~ ": " ~ uuid);

		cfgFile.writeln(Options.LoadOnBoot ~ ": false");
		cfgFile.writeln(Options.CommDelay ~ ": 0.1");
		cfgFile.writeln(Options.WiFiEnabled ~ ": true");
		cfgFile.writeln(Options.BluetoothEnabled ~ ": true");
		cfgFile.writeln(Options.UsbEnabled ~ ": true");

		cfgFile.close();
	}

	static File cfgFile;
	static bool firstTime = false, changed = false, loaded = false;
	static string[string] options;
}