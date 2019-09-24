module extrapanel.core.util.logger;

// Daemonize
import daemonize.d;

// Extra Panel
version (daemon) import extrapanel.core.util.paths;

// STD
import std.experimental.logger;
import std.stdio;

/**
 *	logger.d - Global logger for application
 */

public static FileLogger logger;
public static immutable LogLevel logLevel = LogLevel.all;

// Constructs the logger
void initLogger() {
	// If it's the daemon, the logger needs to be a file since we don't have console I/O
	version(daemon) {
		logger = new FileLogger(buildPath(appConfigPath, LOG_PATH), logLevel);
	} else {
		logger = new FileLogger(stderr, logLevel);
	}
}

synchronized class DaemonizeLogger : IDaemonLogger {
	void logDebug(string message) nothrow
	{
		try {
			logger.trace(message);
		} catch (Exception) {}
	}

	void logInfo(lazy string message) nothrow
	{
		try {
			logger.info(message);
		} catch (Exception) {}
	}

	void logWarning(lazy string message) nothrow
	{
		try {
			logger.warning(message);
		} catch (Exception) {}
	}

	void logError(lazy string message) @trusted nothrow
	{
		try {
			logger.critical(message);
		} catch (Exception) {}
	}

	DaemonLogLevel minLogLevel() @property {return DaemonLogLevel.Debug;}
	void minLogLevel(DaemonLogLevel level) @property {}
	DaemonLogLevel minOutputLevel() @property {return DaemonLogLevel.Debug;}
	void minOutputLevel(DaemonLogLevel level) @property {}
	void finalize() @trusted nothrow {}
	void reload() {}
}