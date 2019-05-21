module extrapanel.paths;

import std.path;
import std.file;

/**
 *	paths.d - Utility methods for path building
 */

public immutable string CONFIG_PATH = "extrapanel.cfg";
public immutable string LOCK_PATH = "daemon.lock";
public immutable string LOG_PATH = "daemonLog.log";
public immutable string PLUGIN_BASE_PATH = "plugins/";

// Creates base paths for the app
public static void createAppPaths() {
	string root = buildPath(expandTilde("~"), ".config");
	if(!exists(buildPath(root, "extrapanel")))
		mkdir(buildPath((root), "extrapanel"));

	if(!exists(buildPath(root, "extrapanel", "plugins")))
		mkdir(buildPath((root), "extrapanel", "plugins"));
}

// Returns the path for the app config
public static string appConfigPath() {
	return buildPath(expandTilde("~"), ".config", "extrapanel/");
}

// Returns the installed plugin path based on it's id
public static string pluginRootPath(string pluginID = null) {
	if(pluginID == null)
		return buildPath(appConfigPath(), "plugins");
	else
		return buildPath(appConfigPath(), "plugins", pluginID ~ "/");
}