module extrapanel.core.util.logger;

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