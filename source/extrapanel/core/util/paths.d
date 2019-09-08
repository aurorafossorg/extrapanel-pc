module extrapanel.core.util.paths;

// STD
public import std.path;
import std.file;

/**
 *	paths.d - Utility methods for path building
 */

public immutable string CONFIG_PATH = "xpanel.cfg";
// FIXME: On Windows, without extensions enabled, both daemon files will look the same and will confuse the user
public immutable string LOCK_PATH = "daemon.lock";
public immutable string LOG_PATH = "daemon.log";
public immutable string APP_BASE_PATH = "extrapanel";
public immutable string PLUGIN_BASE_PATH = "plugins";

public immutable string CDN_PATH = "https://dl.aurorafoss.org/aurorafoss/pub/releases/xpanel-plugins/";

private static string getConfigRootDir() {
	version (Windows) {
		// TODO: Get way of obtaining AppData
		return "null";
	}
	version(OSX) {
		// TODO: Get home folder
		return "null";
	}
	version(linux) {
		return buildPath(expandTilde("~"), ".config");
	}
}

// Creates base paths for the app
public static void createAppPaths() {
	string root = getConfigRootDir();
	if(!exists(root.buildPath(APP_BASE_PATH)))
		mkdir(root.buildPath(APP_BASE_PATH));

	if(!exists(root.buildPath(APP_BASE_PATH, PLUGIN_BASE_PATH)))
		mkdir(root.buildPath(APP_BASE_PATH, PLUGIN_BASE_PATH));
}

// Creates temporary work dir
public static string createTempPath() {
	string root = tempDir.buildPath(APP_BASE_PATH);
	if(!exists(root))
		mkdir(root);
	
	if(!exists(root.buildPath("pc")))
		mkdir(root.buildPath("pc"));

	return root;
}

// Returns the path for the app config
public static string appConfigPath() {
	return buildPath(getConfigRootDir(), APP_BASE_PATH);
}

// Returns the installed plugin path based on it's id
public static string pluginRootPath(string pluginID = null) {
	if(pluginID == null)
		return buildPath(appConfigPath(), PLUGIN_BASE_PATH);
	else
		return buildPath(appConfigPath(), PLUGIN_BASE_PATH, pluginID ~ dirSeparator);
}