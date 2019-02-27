module extrapanel.paths;

import std.path;
import std.file;

public immutable string CONFIG_PATH = "extrapanel.cfg";
public immutable string LOCK_PATH = "daemon.lock";
public immutable string LOG_PATH = "daemonLog.log";

public static void createAppPaths() {
	string root = buildPath(expandTilde("~"), ".config");
	if(!exists(buildPath(root, "extrapanel")))
		mkdir(buildPath((root), "extrapanel"));

	if(!exists(buildPath(root, "extrapanel", "plugins")))
		mkdir(buildPath((root), "extrapanel", "plugins"));
}

public static string appConfigPath() {
	return buildPath(expandTilde("~"), ".config", "extrapanel/");
}

public static string pluginRootPath(string pluginPath) {
	return buildPath(appConfigPath(), "plugins", pluginPath ~ "/");
}