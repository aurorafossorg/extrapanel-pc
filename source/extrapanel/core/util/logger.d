module extrapanel.core.util.logger;

// Daemonize
import daemonize.d;

// Extra Panel
import extrapanel.core.util.paths;

// STD
public import std.experimental.logger;
import std.stdio;

/**
 *	logger.d - Global logger for application
 */

public static immutable LogLevel logLevel = LogLevel.all;

// Constructs the logger
void setupDaemonLogger() {
	// If it's the daemon, the logger needs to be a file since we don't have console I/O
	sharedLog = new FileLogger(buildPath(appConfigPath, LOG_PATH), logLevel);
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

	DaemonLogLevel minLogLevel() @property {return DaemonLogLevel.Debug;}
	void minLogLevel(DaemonLogLevel level) @property {}
	DaemonLogLevel minOutputLevel() @property {return DaemonLogLevel.Debug;}
	void minOutputLevel(DaemonLogLevel level) @property {}
	void finalize() @trusted nothrow {}
	void reload() {}
}