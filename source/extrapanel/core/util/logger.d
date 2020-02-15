module extrapanel.core.util.logger;

// Daemonize
import daemonize.d;

// Extra Panel
import extrapanel.core.util.config;
import extrapanel.core.util.paths;

// STD
public import std.experimental.logger;
import std.stdio;

/**
 *	logger.d - Global logger for application
 */

/// Setup logger level depending on args.
void setupLogLevel() {
	if(Configuration.hasArg(Args.SILENT))
		globalLogLevel = LogLevel.off;
	else if(Configuration.hasArg(Args.VERBOSE))
		globalLogLevel = LogLevel.all;
	else
		debug globalLogLevel = LogLevel.all;
		else globalLogLevel = LogLevel.info;
}

/// Setups a file based logger for the daemon.
void setupDaemonLogger() {
	sharedLog = new FileLogger(buildPath(appConfigPath, LOG_PATH));
}

synchronized class DaemonizeLogger : IDaemonLogger {
	void logDebug(string message) nothrow
	{
		try {
			trace(message);
		} catch (Exception) {}
	}

	void logInfo(lazy string message) nothrow
	{
		try {
			info(message);
		} catch (Exception) {}
	}

	void logWarning(lazy string message) nothrow
	{
		try {
			warning(message);
		} catch (Exception) {}
	}

	void logError(lazy string message) @trusted nothrow
	{
		try {
			critical(message);
		} catch (Exception) {}
	}

	DaemonLogLevel minLogLevel() @property const {return DaemonLogLevel.Debug;}
	void minLogLevel(DaemonLogLevel) @property {}
	DaemonLogLevel minOutputLevel() @property const {return DaemonLogLevel.Debug;}
	void minOutputLevel(DaemonLogLevel) @property const {}
	void finalize() @trusted nothrow {}
	void reload() {}
}
