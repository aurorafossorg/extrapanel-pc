module extrapanel.core.util.paths;

import std.path;
import std.file;

/**
 *	paths.d - Utility methods for path building
 */

public immutable string CONFIG_PATH = "extrapanel.cfg";
public immutable string LOCK_PATH = "daemon.lock";
public immutable string LOG_PATH = "daemonLog.log";
public immutable string PLUGIN_BASE_PATH = "plugins/";

public immutable string CDN_PATH = "https://dl.aurorafoss.org/aurorafoss/pub/releases/xpanel-plugins/";

// Creates base paths for the app
public static void createAppPaths() {
	string root = buildPath(expandTilde("~"), ".config");
	if(!exists(root.buildPath("extrapanel")))
		mkdir(root.buildPath("extrapanel"));

	if(!exists(root.buildPath("extrapanel", "plugins")))
		mkdir(root.buildPath("extrapanel", "plugins"));
}

// Creates temporary work dir
public static string createTempPath() {
	string root = tempDir.buildPath("xpanel");
	if(!exists(root))
		mkdir(root);
	
	if(!exists(root.buildPath("pc")))
		mkdir(root.buildPath("pc"));

	return root;
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