module extrapanel.logger;

import std.experimental.logger;
import std.stdio;

public static FileLogger logger;
public static immutable LogLevel logLevel = LogLevel.all;

void initLogger() {
	version(daemon) {
		import std.path;
		import util.paths;
		logger = new FileLogger(buildPath(appConfigPath ~ LOG_PATH), logLevel);
	} else {
		logger = new FileLogger(stderr, logLevel);
	}
}