module extrapanel.daemon.daemon;

// Core
import core.stdc.stdlib;
import core.sys.posix.signal;
import core.thread;

// Daemominze
import daemonize.d;

// Extra Panel
import extrapanel.core.plugin.info;
import extrapanel.core.script.runner;
import extrapanel.core.util.config;
import extrapanel.core.util.logger;
import extrapanel.core.util.paths;

// STD
import std.conv;
import std.file;
import std.stdio;
import std.math;
import std.parallelism;

immutable string DAEMON_NAME = "extrapanel-daemon";

// Gets the delay in miliseconds from the config file
int getMsecsDelay() {
	return cast(int) round(Configuration.getOption!(float)(Options.CommDelay) * 1000);
}

extern (C) uid_t geteuid();

alias daemon = Daemon!(
	// Unique daemon name
	DAEMON_NAME,

	// Associative mapping of signals -> callbacks
	KeyValueList!(
		Composition!(Signal.Terminate, Signal.Quit, Signal.Shutdown, Signal.Stop), (unusedLogger, signal) {
			info("Exiting...");
			return false;
		},
		Composition!(Signal.HangUp,Signal.Pause,Signal.Continue), (unusedLogger)
		{
			return true;
		}
	),

	// Main daemon function
	(unusedLogger, shouldExit) {
		// Setup our plugin runner
		trace("Loading PluginManager and ScriptRunner...");
		PluginManager pluginManager = PluginManager.getInstance();
		PluginInfo[] plugins = pluginManager.getInstalledPlugins();

		ScriptRunner scriptRunner = ScriptRunner.getInstance();
		foreach(plugin; plugins) {
			trace("Loading plugin \"" ~ plugin.id ~ "\"...");
			scriptRunner.loadPlugin(plugin.id, ScriptType.PLUGIN_SCRIPT);
		}

		// Main loop
		while(!shouldExit()) {
			string query;
			foreach(plugin; taskPool.parallel(plugins)) {
				query ~= "\"" ~ scriptRunner.runQuery(plugin.id) ~ "\", ";
			}
			trace(query);
			Thread.sleep(getMsecsDelay.dur!"msecs");
		}

		// Daemon is quitting
		destroy(scriptRunner);
		info("Daemon is quitting...");

		return 0;
	}
);

ScriptRunner scriptRunner;

int main(string[] args) {
	// Init logger
	setupDaemonLogger();

	// Appends args to global args
	Configuration.appArgs ~= args;
	setupLogLevel();
	
	// Loads general config
	Configuration.load();

	// Builds the required paths and starts the daemon
	string pidPath = buildPath(appConfigPath(), PID_PATH);
	string lockPath = buildPath(appConfigPath(), LOCK_PATH);
	return buildDaemon!daemon.run(new shared DaemonizeLogger(), pidPath, lockPath);
}